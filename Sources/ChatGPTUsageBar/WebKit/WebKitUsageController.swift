import AppKit
import ChatGPTUsageCore
import Combine
import Foundation
import WebKit

@MainActor
final class WebKitUsageController: NSObject, ObservableObject {
    @Published private(set) var refreshingAccountIDs = Set<UUID>()
    @Published private(set) var queuedRefreshAccountIDs: [UUID] = []
    @Published private(set) var refreshPhases: [UUID: UsageRefreshPhase] = [:]

    private weak var store: UsageStore?
    private let refreshQueuePolicy = RefreshQueuePolicy()
    private var loginWindows: [UUID: NSWindow] = [:]
    private var loginWebViews: [UUID: WKWebView] = [:]
    private var popupWindows: [NSWindow] = []
    private var backgroundUsageWebViews: [UUID: WKWebView] = [:]
    private var backgroundUsageWindows: [UUID: NSPanel] = [:]
    private var autoRefreshTask: Task<Void, Never>?
    private var resetRefreshTasks: [UUID: Task<Void, Never>] = [:]
    private var sessionCheckTasks: [UUID: Task<Void, Never>] = [:]
    private var storeCancellables = Set<AnyCancellable>()

    deinit {
        autoRefreshTask?.cancel()
        resetRefreshTasks.values.forEach { $0.cancel() }
        sessionCheckTasks.values.forEach { $0.cancel() }
    }

    func attach(store: UsageStore) {
        self.store = store
        storeCancellables.removeAll()
        store.$settings
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshAutoRefreshSchedule()
            }
            .store(in: &storeCancellables)
        refreshAutoRefreshSchedule()
        rescheduleResetRefreshes()
    }

    func openLogin(account: AccountProfile) {
        if let window = loginWindows[account.id] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            startSessionDetection(for: account)
            return
        }

        let webView = makeWebView(for: account)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.load(URLRequest(url: ChatGPTUsageURLs.login))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "登录 \(account.displayName)"
        window.contentView = LoginBrowserView(webView: webView)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.identifier = NSUserInterfaceItemIdentifier(account.id.uuidString)

        loginWindows[account.id] = window
        loginWebViews[account.id] = webView

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startSessionDetection(for: account)
    }

    func refreshUsage(account: AccountProfile) {
        let account = latestAccount(for: account.id) ?? account
        guard account.loginState.canRefreshUsage else {
            return
        }

        guard !refreshingAccountIDs.contains(account.id),
              !queuedRefreshAccountIDs.contains(account.id) else {
            return
        }

        queuedRefreshAccountIDs.append(account.id)
        setRefreshPhase(.queued, for: account.id)
        drainRefreshQueue()
    }

    private func startRefresh(account: AccountProfile) {
        refreshingAccountIDs.insert(account.id)
        setRefreshPhase(.openingAnalytics, for: account.id)

        Task {
            let snapshot = await readUsage(account: account)
            setRefreshPhase(.savingResult, for: account.id)
            refreshingAccountIDs.remove(account.id)
            store?.updateUsageSnapshot(accountID: account.id, snapshot: snapshot)

            if snapshot.lastFailureKind == .loginRequired {
                store?.updateLoginState(accountID: account.id, loginState: .notLoggedIn)
                resetRefreshTasks[account.id]?.cancel()
                resetRefreshTasks[account.id] = nil
            } else if snapshot.hasUsageData {
                scheduleResetRefresh(
                    accountID: account.id,
                    snapshot: snapshot,
                    allowsImmediateRefresh: false
                )
            } else if await cookieCount(for: account) == 0 {
                store?.updateLoginState(accountID: account.id, loginState: .notLoggedIn)
                resetRefreshTasks[account.id]?.cancel()
                resetRefreshTasks[account.id] = nil
            }

            clearRefreshPhase(for: account.id)
            drainRefreshQueue()
        }
    }

    func deleteAccount(account: AccountProfile) {
        let deletionPlan = AccountDeletionPlan(accountID: account.id)

        if deletionPlan.closesActiveBrowserSurfaces {
            closeBrowserSurfaces(accountID: deletionPlan.accountID)
        }

        if deletionPlan.clearsLocalWebSession {
            Task { [weak self] in
                await self?.clearWebsiteData(for: deletionPlan.accountID)
            }
        }

        store?.deleteAccount(id: deletionPlan.accountID)
    }

    private func drainRefreshQueue() {
        let startableAccountIDs = refreshQueuePolicy.startableAccountIDs(
            queuedAccountIDs: queuedRefreshAccountIDs,
            refreshingAccountIDs: refreshingAccountIDs
        )
        guard !startableAccountIDs.isEmpty else {
            return
        }

        for accountID in startableAccountIDs {
            queuedRefreshAccountIDs.removeAll { $0 == accountID }

            guard let account = latestAccount(for: accountID),
                  account.loginState.canRefreshUsage else {
                clearRefreshPhase(for: accountID)
                continue
            }

            startRefresh(account: account)
        }

        if !queuedRefreshAccountIDs.isEmpty {
            drainRefreshQueue()
        }
    }

    func refreshAllLoggedInAccounts() {
        guard let store else {
            return
        }

        for account in store.accounts where account.loginState.canRefreshUsage {
            refreshUsage(account: account)
        }
    }

    func refreshAutoRefreshSchedule() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil

        guard let store,
              store.autoRefreshSettings.isEnabled,
              !store.accounts.isEmpty else {
            return
        }

        autoRefreshTask = Task { [weak self] in
            await self?.runAutoRefreshLoop()
        }
    }

    private func runAutoRefreshLoop() async {
        var cycleIndex = 0

        while !Task.isCancelled {
            guard let store,
                  store.autoRefreshSettings.isEnabled else {
                break
            }

            let delaySeconds = AutoRefreshSchedule.delaySecondsBeforeRefresh(
                cycleIndex: cycleIndex,
                interval: store.autoRefreshSettings.interval
            )

            if delaySeconds > 0 {
                try? await Task.sleep(for: .seconds(delaySeconds))
            }

            guard !Task.isCancelled,
                  let refreshedStore = self.store,
                  refreshedStore.autoRefreshSettings.isEnabled else {
                break
            }

            for account in autoRefreshAccounts(from: refreshedStore) {
                refreshUsage(account: account)
            }

            cycleIndex += 1
        }
    }

    private func autoRefreshAccounts(from store: UsageStore) -> [AccountProfile] {
        switch store.autoRefreshSettings.target {
        case .currentAccount:
            guard let selectedAccountID = store.selectedAccountID,
                  let account = store.accounts.first(where: { $0.id == selectedAccountID }),
                  account.loginState.canRefreshUsage else {
                return []
            }

            return [account]
        case .allAccounts:
            return store.accounts.filter { $0.loginState.canRefreshUsage }
        }
    }

    private func latestAccount(for accountID: UUID) -> AccountProfile? {
        store?.accounts.first { $0.id == accountID }
    }

    private func setRefreshPhase(_ phase: UsageRefreshPhase, for accountID: UUID) {
        refreshPhases[accountID] = phase
    }

    private func clearRefreshPhase(for accountID: UUID) {
        refreshPhases[accountID] = nil
    }

    private func startSessionDetection(for account: AccountProfile) {
        sessionCheckTasks[account.id]?.cancel()
        sessionCheckTasks[account.id] = Task { [weak self] in
            for attempt in 0..<30 {
                guard !Task.isCancelled,
                      let self else {
                    return
                }

                try? await Task.sleep(for: .seconds(attempt == 0 ? 1 : 2))

                guard !Task.isCancelled else {
                    return
                }

                let cookieCount = await self.cookieCount(for: account)
                if cookieCount > 0 {
                    guard await self.loginSessionIsVerified(for: account, cookieCount: cookieCount) else {
                        continue
                    }

                    let previousAccount = self.latestAccount(for: account.id) ?? account
                    self.store?.updateLoginState(
                        accountID: account.id,
                        loginState: .sessionDetected
                    )
                    if FirstUsageRefreshPolicy.shouldRefreshAfterSessionDetected(account: previousAccount),
                       let refreshedAccount = self.latestAccount(for: account.id) {
                        self.refreshUsage(account: refreshedAccount)
                    }
                    self.sessionCheckTasks[account.id] = nil
                    return
                }
            }

            self?.sessionCheckTasks[account.id] = nil
        }
    }

    private func loginSessionIsVerified(for account: AccountProfile, cookieCount: Int) async -> Bool {
        guard let webView = loginWebViews[account.id] else {
            return false
        }

        let currentURL = await currentLocationString(from: webView)
        let payload = (try? await webView.evaluateJavaScript(Self.diagnosticJavaScript()) as? String) ?? ""
        return AccountSessionVerification.canTrustCookieSession(
            cookieCount: cookieCount,
            urlString: currentURL,
            visibleText: payload
        )
    }

    func rescheduleResetRefreshes() {
        resetRefreshTasks.values.forEach { $0.cancel() }
        resetRefreshTasks = [:]

        guard let store else {
            return
        }

        for account in store.accounts where account.loginState.canRefreshUsage {
            scheduleResetRefresh(
                accountID: account.id,
                snapshot: account.resolvedUsageSnapshot,
                allowsImmediateRefresh: true
            )
        }
    }

    private func scheduleResetRefresh(
        accountID: UUID,
        snapshot: UsageSnapshot,
        allowsImmediateRefresh: Bool
    ) {
        resetRefreshTasks[accountID]?.cancel()
        resetRefreshTasks[accountID] = nil

        guard snapshot.hasUsageData else {
            return
        }

        let decision = UsageResetSchedule.refreshDecision(snapshot: snapshot)

        if decision.shouldRefreshNow {
            guard allowsImmediateRefresh,
                  !refreshingAccountIDs.contains(accountID),
                  let account = latestAccount(for: accountID),
                  account.loginState.canRefreshUsage else {
                return
            }

            refreshUsage(account: account)
            return
        }

        guard let resetDate = decision.nextRefreshDate else {
            return
        }

        let delay = max(0, resetDate.timeIntervalSinceNow)
        resetRefreshTasks[accountID] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))

            guard !Task.isCancelled,
                  let self,
                  !self.refreshingAccountIDs.contains(accountID),
                  let account = self.latestAccount(for: accountID),
                  account.loginState.canRefreshUsage else {
                return
            }

            self.resetRefreshTasks[accountID] = nil
            self.refreshUsage(account: account)
        }
    }

    private func readUsage(account: AccountProfile) async -> UsageSnapshot {
        let webView = backgroundUsageWebViews[account.id] ?? makeWebView(for: account)
        backgroundUsageWebViews[account.id] = webView
        webView.navigationDelegate = self
        webView.uiDelegate = self
        mountBackgroundWebView(webView, for: account)

        setRefreshPhase(.openingAnalytics, for: account.id)
        var snapshot = await readAnalyticsUsage(from: webView, account: account)
        if snapshot.lastFailureKind != .loginRequired {
            setRefreshPhase(.readingSubscription, for: account.id)
        }
        if snapshot.lastFailureKind != .loginRequired,
           let subscriptionExpiryText = await readSubscriptionExpiryText(from: webView) {
            snapshot.subscriptionExpiryText = subscriptionExpiryText
        }

        return snapshot.preservingSubscriptionExpiry(from: account.resolvedUsageSnapshot)
    }

    private func readAnalyticsUsage(from webView: WKWebView, account: AccountProfile) async -> UsageSnapshot {
        setRefreshPhase(.openingAnalytics, for: account.id)
        webView.load(URLRequest(url: ChatGPTUsageURLs.analytics))

        var lastSnapshot = UsageSnapshot.empty
        var lastError: String?
        var lastFailureKind: UsageReadFailureKind?
        var consecutiveLoadingAttempts = 0
        var loadingReloadCount = 0

        for attempt in 0..<24 {
            try? await Task.sleep(for: .seconds(attempt == 0 ? 8 : 2))

            do {
                setRefreshPhase(.checkingLogin, for: account.id)
                let currentURL = await currentLocationString(from: webView)
                if UsageAnalyticsReadiness.isLoginRequiredPage(urlString: currentURL, visibleText: "") {
                    return failureSnapshot(kind: .loginRequired)
                }

                guard UsageAnalyticsReadiness.isExpectedAnalyticsURL(currentURL) else {
                    consecutiveLoadingAttempts = 0
                    lastFailureKind = .unexpectedPage
                    lastError = lastFailureKind?.displayMessage
                    setRefreshPhase(.openingAnalytics, for: account.id)

                    if attempt == 0 || attempt % 3 == 2 {
                        reloadAnalyticsPage(webView)
                        try? await Task.sleep(for: .seconds(3))
                    }
                    continue
                }

                setRefreshPhase(.readingAnalytics, for: account.id)
                let payload = try await webView.evaluateJavaScript(Self.usageExtractionJavaScript()) as? String ?? ""
                var snapshot = UsageSnapshotParser.parse(visibleText: payload)
                let foundUsage = snapshot.fiveHourUsage != nil || snapshot.weeklyUsage != nil
                lastSnapshot = snapshot

                if foundUsage {
                    snapshot.lastError = nil
                    return snapshot
                }

                let diagnostics = try await readDiagnostics(from: webView, account: account)
                if UsageAnalyticsReadiness.isLoginRequiredPage(
                    urlString: currentURL,
                    visibleText: diagnostics.payload
                ) {
                    return failureSnapshot(kind: .loginRequired)
                }

                if UsageAnalyticsReadiness.isStillLoading(payload)
                    || UsageAnalyticsReadiness.isStillLoading(diagnostics.payload) {
                    consecutiveLoadingAttempts += 1
                    lastFailureKind = .analyticsLoading
                    lastError = lastFailureKind?.displayMessage
                    setRefreshPhase(.waitingForAnalytics, for: account.id)

                    if consecutiveLoadingAttempts >= 3 && loadingReloadCount < 2 {
                        reloadAnalyticsPage(webView)
                        loadingReloadCount += 1
                        consecutiveLoadingAttempts = 0
                        try? await Task.sleep(for: .seconds(4))
                    }
                    continue
                }

                consecutiveLoadingAttempts = 0
                lastFailureKind = UsageAnalyticsReadiness.failureKindForMissingUsage(
                    urlString: currentURL,
                    visibleText: diagnostics.payload
                )
                lastError = lastFailureKind?.displayMessage ?? diagnosticMessage(from: diagnostics)
            } catch {
                consecutiveLoadingAttempts = 0
                lastFailureKind = .webKitEvaluation
                lastError = "\(UsageReadFailureKind.webKitEvaluation.displayMessage) \(error.localizedDescription)"
            }
        }

        lastSnapshot.lastReadAt = Date()
        lastSnapshot.lastFailureKind = lastFailureKind ?? .timeout
        lastSnapshot.lastError = lastError ?? lastSnapshot.lastFailureKind?.displayMessage
        return lastSnapshot
    }

    private func failureSnapshot(kind: UsageReadFailureKind) -> UsageSnapshot {
        UsageSnapshot(
            lastReadAt: Date(),
            lastError: kind.displayMessage,
            lastFailureKind: kind
        )
    }

    private func reloadAnalyticsPage(_ webView: WKWebView) {
        if UsageAnalyticsReadiness.isExpectedAnalyticsURL(webView.url?.absoluteString) {
            webView.reloadFromOrigin()
        } else {
            webView.load(URLRequest(url: ChatGPTUsageURLs.analytics))
        }
    }

    private func currentLocationString(from webView: WKWebView) async -> String? {
        do {
            return try await webView.evaluateJavaScript("location.href") as? String
        } catch {
            return webView.url?.absoluteString
        }
    }

    private func readSubscriptionExpiryText(from webView: WKWebView) async -> String? {
        webView.load(URLRequest(url: ChatGPTUsageURLs.billing))
        defer {
            reloadAnalyticsPage(webView)
        }

        for attempt in 0..<12 {
            try? await Task.sleep(for: .seconds(attempt == 0 ? 5 : 1))

            do {
                let payload = try await webView.evaluateJavaScript(Self.billingExtractionJavaScript()) as? String ?? ""
                let snapshot = UsageSnapshotParser.parse(visibleText: payload)

                if let subscriptionExpiryText = snapshot.subscriptionExpiryText {
                    return subscriptionExpiryText
                }
            } catch {
                continue
            }
        }

        return nil
    }

    private func readDiagnostics(from webView: WKWebView, account: AccountProfile) async throws -> WebKitUsageDiagnostics {
        let payload = try await webView.evaluateJavaScript(Self.diagnosticJavaScript()) as? String ?? ""
        let cookieCount = await cookieCount(for: account)
        return WebKitUsageDiagnostics(payload: payload, cookieCount: cookieCount)
    }

    private func cookieCount(for account: AccountProfile) async -> Int {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore(forIdentifier: account.id).httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies.count)
            }
        }
    }

    private func clearWebsiteData(for accountID: UUID) async {
        await withCheckedContinuation { continuation in
            let dataStore = WKWebsiteDataStore(forIdentifier: accountID)
            dataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: .distantPast
            ) {
                continuation.resume()
            }
        }
    }

    private func closeBrowserSurfaces(accountID: UUID) {
        sessionCheckTasks[accountID]?.cancel()
        sessionCheckTasks[accountID] = nil
        resetRefreshTasks[accountID]?.cancel()
        resetRefreshTasks[accountID] = nil
        refreshingAccountIDs.remove(accountID)
        queuedRefreshAccountIDs.removeAll { $0 == accountID }
        clearRefreshPhase(for: accountID)

        if let loginWindow = loginWindows[accountID] {
            loginWindow.delegate = nil
            loginWindow.contentView = nil
            loginWindow.close()
        }
        loginWindows[accountID] = nil
        loginWebViews[accountID] = nil

        if let backgroundWindow = backgroundUsageWindows[accountID] {
            backgroundWindow.contentView = nil
            backgroundWindow.close()
        }
        backgroundUsageWindows[accountID] = nil
        backgroundUsageWebViews[accountID] = nil
    }

    private func makeWebView(for account: AccountProfile) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = WKWebsiteDataStore(forIdentifier: account.id)
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        return WKWebView(
            frame: NSRect(x: 0, y: 0, width: 1080, height: 760),
            configuration: configuration
        )
    }

    private func mountBackgroundWebView(_ webView: WKWebView, for account: AccountProfile) {
        if let window = backgroundUsageWindows[account.id] {
            if window.contentView !== webView {
                window.contentView = webView
            }
            window.orderFrontRegardless()
            return
        }

        let window = NSPanel(
            contentRect: NSRect(x: -20000, y: -20000, width: 1080, height: 760),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.contentView = webView
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.ignoresMouseEvents = true
        window.alphaValue = 0.02
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        window.orderFrontRegardless()

        backgroundUsageWindows[account.id] = window
    }

    private static func usageExtractionJavaScript() -> String {
        """
        (() => {
          const extractionVersion = "usage-extraction-v2";
          const normalize = (value) => String(value || "").replace(/\\s+/g, " ").trim();
          try {
            window.scrollTo({ top: 0, behavior: "instant" });
          } catch (_) {
            window.scrollTo(0, 0);
          }

          const out = [];
          const seen = new Set();
          const add = (value) => {
            if (!value) return;
            String(value)
              .split(/\\n+/)
              .map((item) => item.trim())
              .filter(Boolean)
              .forEach((item) => {
                const key = item.toLowerCase();
                if (!seen.has(key)) {
                  seen.add(key);
                  out.push(item);
                }
              });
          };

          const articleSummaries = [];
          const structuredCards = [];
          const usageKind = (value) => {
            const text = normalize(value).toLowerCase();
            if (/(5\\s*小时|5\\s*h|5-hour|5\\s*hour|five[-\\s]?hour)/i.test(text)) return "5h";
            if (/(每周|一周|1\\s*w|week|weekly)/i.test(text)) return "1w";
            return "";
          };
          document.querySelectorAll("article").forEach((article) => {
            const text = normalize(article.innerText);
            if (!/(5\\s*小时|每周|week|5\\s*h|5-hour|usage|限额)/i.test(text)) return;
            const title = normalize(article.querySelector("p")?.innerText);
            const percent = normalize(article.querySelector(".text-2xl")?.innerText || (text.match(/\\d+(?:\\.\\d+)?%/) || [""])[0]);
            const reset = normalize(Array.from(article.querySelectorAll("span")).map((span) => span.innerText).find((value) => /重置|reset/i.test(value)));
            const bar = normalize(Array.from(article.querySelectorAll('[style*="width"]')).map((element) => element.style.width).filter(Boolean).pop());
            const kind = usageKind([title, text].join(" "));
            if (kind && percent) {
              structuredCards.push([
                "USAGE_CARD",
                `kind=${kind}`,
                `remaining=${percent}`,
                reset ? `reset=${reset}` : ""
              ].filter(Boolean).join(" | "));
            }
            articleSummaries.push(["CARD", title, percent, bar, reset, text].filter(Boolean).join(" | "));
          });

          if (structuredCards.length) add(structuredCards.join("\\n"));
          if (articleSummaries.length) add(articleSummaries.join("\\n"));
          add(document.body ? document.body.innerText : "");
          document.querySelectorAll("[aria-label],[title]").forEach((element) => {
            add(element.getAttribute("aria-label"));
            add(element.getAttribute("title"));
          });
          document.querySelectorAll("svg text").forEach((element) => add(element.textContent));
          document.querySelectorAll('[role="progressbar"]').forEach((element) => {
            const label = element.getAttribute("aria-label") || "";
            const now = element.getAttribute("aria-valuenow") || "";
            const min = element.getAttribute("aria-valuemin") || "";
            const max = element.getAttribute("aria-valuemax") || "";
            add(["progressbar", label, now, min, max].filter(Boolean).join(" "));
          });
          out.unshift([
            "EXTRACTION_DIAGNOSTICS",
            `version=${extractionVersion}`,
            `structuredCards=${structuredCards.length}`,
            `articleCards=${articleSummaries.length}`,
            `usageSignalLines=${out.length}`
          ].join(" | "));
          return out.join("\\n");
        })()
        """
    }

    private static func diagnosticJavaScript() -> String {
        """
        (() => {
          const text = String(document.body ? document.body.innerText : "")
            .replace(/\\s+/g, " ")
            .trim()
            .slice(0, 220);
          return [
            `URL=${location.href}`,
            `TITLE=${document.title}`,
            `TEXT=${text}`
          ].join("\\n");
        })()
        """
    }

    private static func billingExtractionJavaScript() -> String {
        """
        (() => {
          const normalize = (value) => String(value || "").replace(/\\s+/g, " ").trim();
          if (!location.hash.toLowerCase().includes("settings/billing")) {
            location.hash = "#settings/Billing";
          }

          const out = [];
          const seen = new Set();
          const add = (value) => {
            const text = normalize(value);
            if (!text) return;
            text.split(/\\n+/)
              .map((item) => normalize(item))
              .filter(Boolean)
              .forEach((item) => {
                const key = item.toLowerCase();
                if (!seen.has(key)) {
                  seen.add(key);
                  out.push(item);
                }
              });
          };

          document.querySelectorAll("h2, h3, p, button").forEach((element) => {
            add(element.innerText || element.textContent);
          });
          document.querySelectorAll("section, [role='dialog']").forEach((element) => {
            add(element.innerText || element.textContent);
          });
          add(document.body ? document.body.innerText : "");
          return out.join("\\n");
        })()
        """
    }
}

private struct WebKitUsageDiagnostics {
    let payload: String
    let cookieCount: Int
}

private func diagnosticMessage(from diagnostics: WebKitUsageDiagnostics) -> String {
    let compactPayload = diagnostics.payload
        .components(separatedBy: .newlines)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")

    return "未发现用量卡片。Cookie \(diagnostics.cookieCount) 个。\(compactPayload)"
}

private final class LoginBrowserView: NSView {
    private let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        buildView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private func buildView() {
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 8
        toolbar.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        let backButton = makeIconButton("chevron.left", help: "后退", action: #selector(goBack))
        let forwardButton = makeIconButton("chevron.right", help: "前进", action: #selector(goForward))
        let reloadButton = makeIconButton("arrow.clockwise", help: "刷新", action: #selector(reload))
        let loginButton = NSButton(title: "登录页", target: self, action: #selector(openLoginPage))
        loginButton.bezelStyle = .rounded
        loginButton.controlSize = .small

        toolbar.addArrangedSubview(backButton)
        toolbar.addArrangedSubview(forwardButton)
        toolbar.addArrangedSubview(reloadButton)
        toolbar.addArrangedSubview(loginButton)
        toolbar.addArrangedSubview(NSView())

        webView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(toolbar)
        addSubview(webView)

        NSLayoutConstraint.activate([
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 42),

            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func makeIconButton(_ symbolName: String, help: String, action: Selector) -> NSButton {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: help)
        let button = NSButton(image: image ?? NSImage(), target: self, action: action)
        button.bezelStyle = .texturedRounded
        button.controlSize = .small
        button.toolTip = help
        return button
    }

    @objc private func goBack() {
        if webView.canGoBack {
            webView.goBack()
        } else {
            openLoginPage()
        }
    }

    @objc private func goForward() {
        if webView.canGoForward {
            webView.goForward()
        }
    }

    @objc private func reload() {
        webView.reload()
    }

    @objc private func openLoginPage() {
        webView.load(URLRequest(url: ChatGPTUsageURLs.login))
    }

    func contains(webView: WKWebView) -> Bool {
        self.webView === webView
    }
}

extension WebKitUsageController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else {
            return nil
        }

        let popupWebView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 780, height: 720),
            configuration: configuration
        )
        popupWebView.navigationDelegate = self
        popupWebView.uiDelegate = self

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "登录验证"
        window.contentView = LoginBrowserView(webView: popupWebView)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        popupWindows.append(window)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        return popupWebView
    }

    func webViewDidClose(_ webView: WKWebView) {
        guard let window = popupWindows.first(where: { window in
            guard let browserView = window.contentView as? LoginBrowserView else {
                return false
            }

            return browserView.contains(webView: webView)
        }) else {
            return
        }

        window.close()
    }
}

extension WebKitUsageController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else {
            return
        }

        popupWindows.removeAll { $0 === window }

        guard let accountID = window.identifier.flatMap({ UUID(uuidString: $0.rawValue) }) else {
            return
        }

        loginWindows[accountID] = nil
        window.contentView = nil
        loginWebViews[accountID] = nil
    }
}

extension WebKitUsageController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        return .allow
    }
}

private enum ChatGPTUsageURLs {
    static let login = URL(string: "https://chatgpt.com/auth/login")!
    static let analytics = URL(string: "https://chatgpt.com/codex/cloud/settings/analytics")!
    static let billing = URL(string: "https://chatgpt.com/#settings/Billing")!
}
