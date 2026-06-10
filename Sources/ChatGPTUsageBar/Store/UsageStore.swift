import ChatGPTUsageCore
import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var accounts: [AccountProfile] = []
    @Published private(set) var settings = UsageStoreSettings()
    @Published var lastError: String?

    private let fileURL: URL
    private let settingsURL: URL
    private var footerQuoteRotationTask: Task<Void, Never>?

    init(fileURL: URL? = nil, settingsURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultStoreURL()
        self.settingsURL = settingsURL ?? Self.defaultSettingsURL()
        load()
        rotateFooterQuoteIfNeeded()
        startFooterQuoteRotationTask()
    }

    deinit {
        footerQuoteRotationTask?.cancel()
    }

    var selectedAccountID: UUID? {
        settings.selectedAccountID
    }

    var autoRefreshSettings: AutoRefreshSettings {
        settings.autoRefresh
    }

    var refreshEffectSettings: RefreshEffectSettings {
        settings.refreshEffects
    }

    var themePreference: AppThemePreference {
        settings.themePreference
    }

    var footerQuoteText: String {
        FooterQuoteCatalog.phrase(at: settings.footerQuote.currentIndex)
    }

    var dataDirectoryURL: URL {
        fileURL.deletingLastPathComponent()
    }

    var dataDirectoryPath: String {
        dataDirectoryURL.path
    }

    var accountsFilePath: String {
        fileURL.path
    }

    var settingsFilePath: String {
        settingsURL.path
    }

    func makeNewAccount() -> AccountProfile {
        AccountProfile.starter(profileDirectory: nextAvailableChromeProfileName())
    }

    func add(_ account: AccountProfile) {
        var account = account
        account.chromeProfileDirectory = uniqueChromeProfileName(
            preferred: account.chromeProfileDirectory,
            excludingAccountID: account.id
        )
        account.createdAt = Date()
        account.updatedAt = Date()
        accounts.append(account)
        if settings.selectedAccountID == nil {
            settings.selectedAccountID = account.id
            saveSettings()
        }
        save()
    }

    func update(_ account: AccountProfile) {
        guard let index = accounts.firstIndex(where: { $0.id == account.id }) else {
            return
        }

        var account = account
        account.chromeProfileDirectory = uniqueChromeProfileName(
            preferred: account.chromeProfileDirectory,
            excludingAccountID: account.id
        )
        account.updatedAt = Date()
        accounts[index] = account
        accounts = AccountProfileOrdering.normalized(accounts)
        save()
    }

    func deleteAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        normalizeSelectedAccount()
        save()
    }

    func selectCurrentAccount(accountID: UUID) {
        guard accounts.contains(where: { $0.id == accountID }),
              settings.selectedAccountID != accountID else {
            return
        }

        settings.selectedAccountID = accountID
        saveSettings()
    }

    func setAutoRefreshEnabled(_ isEnabled: Bool) {
        guard settings.autoRefresh.isEnabled != isEnabled else {
            return
        }

        settings.autoRefresh.isEnabled = isEnabled
        normalizeSelectedAccount()
        saveSettings()
    }

    func setAutoRefreshTarget(_ target: AutoRefreshTarget) {
        guard settings.autoRefresh.target != target else {
            return
        }

        settings.autoRefresh.target = target
        normalizeSelectedAccount()
        saveSettings()
    }

    func setAutoRefreshInterval(_ interval: AutoRefreshInterval) {
        guard settings.autoRefresh.interval != interval else {
            return
        }

        settings.autoRefresh.interval = interval
        saveSettings()
    }

    func setRefreshEffectsEnabled(_ isEnabled: Bool) {
        guard settings.refreshEffects.isEnabled != isEnabled else {
            return
        }

        settings.refreshEffects.isEnabled = isEnabled
        saveSettings()
    }

    func setAutoRefreshEffectsEnabled(_ isEnabled: Bool) {
        guard settings.refreshEffects.isAutoRefreshEnabled != isEnabled else {
            return
        }

        settings.refreshEffects.isAutoRefreshEnabled = isEnabled
        saveSettings()
    }

    func setThemePreference(_ themePreference: AppThemePreference) {
        guard settings.themePreference != themePreference else {
            return
        }

        settings.themePreference = themePreference
        saveSettings()
    }

    func rotateFooterQuoteIfNeeded(
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        let nextSettings = FooterQuoteRotation.rotateIfNeeded(
            settings.footerQuote,
            now: now,
            calendar: calendar
        )

        guard nextSettings != settings.footerQuote else {
            return
        }

        settings.footerQuote = nextSettings
        saveSettings()
    }

    func advanceFooterQuote(
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        settings.footerQuote = FooterQuoteRotation.advanceManually(
            settings.footerQuote,
            now: now,
            calendar: calendar
        )
        saveSettings()
    }

    func togglePinned(accountID: UUID) {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else {
            return
        }

        var account = accounts.remove(at: index)
        account.isPinned.toggle()
        account.updatedAt = Date()

        if account.isPinned {
            accounts.insert(account, at: 0)
        } else {
            accounts.insert(account, at: min(index, accounts.count))
        }

        accounts = AccountProfileOrdering.normalized(accounts)
        save()
    }

    func moveAccount(sourceID: UUID, beforeTargetID targetID: UUID?) {
        let reorderedAccounts = AccountProfileOrdering.moving(
            accounts,
            sourceID: sourceID,
            beforeTargetID: targetID
        )

        guard reorderedAccounts.map(\.id) != accounts.map(\.id) else {
            return
        }

        accounts = reorderedAccounts
        save()
    }

    func updateUsageSnapshot(accountID: UUID, snapshot: UsageSnapshot) {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else {
            return
        }

        let snapshot = snapshot.removingAnalyticsFilterChromeUsage()
        if snapshot.hasUsageData {
            accounts[index].usageSnapshot = snapshot
            accounts[index].loginState = .confirmed
        } else {
            accounts[index].usageSnapshot = accounts[index].resolvedUsageSnapshot
                .preservingUsageData(afterFailedRead: snapshot)
        }
        accounts[index].updatedAt = Date()
        save()
    }

    func updateLoginState(
        accountID: UUID,
        loginState: AccountLoginState,
        checkedAt: Date = Date()
    ) {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }),
              accounts[index].loginState != loginState || accounts[index].lastSessionCheckAt != checkedAt else {
            return
        }

        accounts[index].loginState = loginState
        accounts[index].lastSessionCheckAt = checkedAt
        accounts[index].updatedAt = Date()
        save()
    }

    func markUsageReadError(accountID: UUID, message: String) {
        guard let index = accounts.firstIndex(where: { $0.id == accountID }) else {
            return
        }

        var snapshot = accounts[index].resolvedUsageSnapshot
        snapshot.lastError = message
        snapshot.lastReadAt = Date()
        accounts[index].usageSnapshot = snapshot
        accounts[index].updatedAt = Date()
        save()
    }

    private func load() {
        loadAccounts()
        loadSettings()
        normalizeSelectedAccount()
    }

    private func startFooterQuoteRotationTask() {
        footerQuoteRotationTask?.cancel()
        footerQuoteRotationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))

                guard !Task.isCancelled else {
                    return
                }

                self?.rotateFooterQuoteIfNeeded()
            }
        }
    }

    private func loadAccounts() {
        do {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                accounts = []
                return
            }

            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            accounts = try decoder.decode([AccountProfile].self, from: data)
            normalizeChromeProfiles()
            normalizePinnedAccounts()
            lastError = nil
        } catch {
            lastError = "读取本地数据失败：\(error.localizedDescription)"
            accounts = []
        }
    }

    private func loadSettings() {
        do {
            guard FileManager.default.fileExists(atPath: settingsURL.path) else {
                settings = UsageStoreSettings()
                return
            }

            let data = try Data(contentsOf: settingsURL)
            settings = try JSONDecoder().decode(UsageStoreSettings.self, from: data)
            lastError = nil
        } catch {
            lastError = "读取本地设置失败：\(error.localizedDescription)"
            settings = UsageStoreSettings()
        }
    }

    private func normalizePinnedAccounts() {
        let normalizedAccounts = AccountProfileOrdering.normalized(accounts)
        guard normalizedAccounts.map(\.id) != accounts.map(\.id) else {
            return
        }

        accounts = normalizedAccounts
        save()
    }

    private func normalizeSelectedAccount() {
        guard !accounts.isEmpty else {
            if settings.selectedAccountID != nil {
                settings.selectedAccountID = nil
                saveSettings()
            }
            return
        }

        if let selectedAccountID = settings.selectedAccountID,
           accounts.contains(where: { $0.id == selectedAccountID }) {
            return
        }

        settings.selectedAccountID = accounts.first?.id
        saveSettings()
    }

    private func normalizeChromeProfiles() {
        var usedNames = Set<String>()
        var didChange = false

        for index in accounts.indices {
            let original = accounts[index].chromeProfileDirectory
            let preferred = original.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = uniqueChromeProfileName(
                preferred: preferred,
                usedNames: usedNames,
                fallbackIndex: index
            )

            accounts[index].chromeProfileDirectory = normalized
            if accounts[index].usageSnapshot == nil {
                accounts[index].usageSnapshot = .empty
                didChange = true
            }
            usedNames.insert(normalized.lowercased())

            if original != normalized {
                didChange = true
            }
        }

        if didChange {
            save()
        }
    }

    private func uniqueChromeProfileName(preferred: String, excludingAccountID accountID: UUID) -> String {
        let usedNames = Set(
            accounts
                .filter { $0.id != accountID }
                .map { $0.chromeProfileDirectory.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )

        return uniqueChromeProfileName(
            preferred: preferred,
            usedNames: usedNames,
            fallbackIndex: accounts.count
        )
    }

    private func uniqueChromeProfileName(
        preferred: String,
        usedNames: Set<String>,
        fallbackIndex: Int
    ) -> String {
        let trimmedPreferred = preferred.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedPreferred.isEmpty && !usedNames.contains(trimmedPreferred.lowercased()) {
            return trimmedPreferred
        }

        var index = fallbackIndex
        while true {
            let candidate = AccountProfile.defaultChromeProfileName(forAccountIndex: index)
            if !usedNames.contains(candidate.lowercased()) {
                return candidate
            }
            index += 1
        }
    }

    private func nextAvailableChromeProfileName() -> String {
        let usedNames = Set(
            accounts.map { $0.chromeProfileDirectory.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        )
        return uniqueChromeProfileName(preferred: "", usedNames: usedNames, fallbackIndex: accounts.count)
    }

    private func save() {
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(accounts)
            try data.write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "保存本地数据失败：\(error.localizedDescription)"
        }
    }

    private func saveSettings() {
        do {
            let directory = settingsURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(settings)
            try data.write(to: settingsURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = "保存本地设置失败：\(error.localizedDescription)"
        }
    }

    private static func defaultStoreURL() -> URL {
        defaultBaseURL()
            .appendingPathComponent("accounts.json")
    }

    private static func defaultSettingsURL() -> URL {
        defaultBaseURL()
            .appendingPathComponent("settings.json")
    }

    private static func defaultBaseURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser

        return baseURL
            .appendingPathComponent("ChatGPTUsageBar", isDirectory: true)
    }
}
