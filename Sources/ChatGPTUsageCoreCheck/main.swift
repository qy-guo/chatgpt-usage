import ChatGPTUsageCore
import Foundation

func checkDefaultProfileNames() {
    precondition(AccountProfile.defaultChromeProfileName(forAccountIndex: 0) == "Default")
    precondition(AccountProfile.defaultChromeProfileName(forAccountIndex: 1) == "Profile 1")
    precondition(AccountProfile.defaultChromeProfileName(forAccountIndex: 2) == "Profile 2")
}

func checkAccountRoundTrip() throws {
    let sessionCheckDate = Date(timeIntervalSince1970: 1_800)
    let account = AccountProfile(
        displayName: "测试账号",
        accountHint: "test@example.com",
        subscription: .plus,
        chromeProfileDirectory: "Profile 1",
        isPinned: true,
        loginState: .sessionDetected,
        lastSessionCheckAt: sessionCheckDate,
        createdAt: Date(timeIntervalSince1970: 1_000),
        updatedAt: Date(timeIntervalSince1970: 2_000)
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(account)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(AccountProfile.self, from: data)

    precondition(decoded.displayName == account.displayName)
    precondition(decoded.chromeProfileDirectory == "Profile 1")
    precondition(decoded.subscription == .plus)
    precondition(decoded.isPinned)
    precondition(decoded.loginState == .sessionDetected)
    precondition(decoded.lastSessionCheckAt == sessionCheckDate)
}

func checkAccountLoginStateDefaultsAndEligibility() throws {
    let starter = AccountProfile.starter(profileDirectory: "Default")
    precondition(starter.loginState == .notLoggedIn)
    precondition(!starter.loginState.canRefreshUsage)
    precondition(AccountLoginState.sessionDetected.canRefreshUsage)
    precondition(AccountLoginState.confirmed.canRefreshUsage)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let legacyWithUsage = """
    {
      "id": "00000000-0000-0000-0000-000000000031",
      "displayName": "legacy-usage",
      "accountHint": "",
      "subscription": "plus",
      "chromeProfileDirectory": "Default",
      "usageSnapshot": {
        "fiveHourUsage": "50% 剩余 · 重置时间：1:32",
        "lastReadAt": "2026-05-24T10:00:00Z"
      },
      "isPinned": false,
      "createdAt": "2026-05-24T09:00:00Z",
      "updatedAt": "2026-05-24T10:00:00Z"
    }
    """.data(using: .utf8)!

    let decodedLegacyWithUsage = try decoder.decode(AccountProfile.self, from: legacyWithUsage)
    precondition(decodedLegacyWithUsage.loginState == .confirmed)

    let legacyWithoutUsage = """
    {
      "id": "00000000-0000-0000-0000-000000000032",
      "displayName": "legacy-empty",
      "accountHint": "",
      "subscription": "plus",
      "chromeProfileDirectory": "Profile 1",
      "isPinned": false,
      "createdAt": "2026-05-24T09:00:00Z",
      "updatedAt": "2026-05-24T10:00:00Z"
    }
    """.data(using: .utf8)!

    let decodedLegacyWithoutUsage = try decoder.decode(AccountProfile.self, from: legacyWithoutUsage)
    precondition(decodedLegacyWithoutUsage.loginState == .notLoggedIn)
}

func checkUsageSnapshotParser() {
    let snapshot = UsageSnapshotParser.parse(
        visibleText: """
        Codex usage
        5h usage
        12 of 50 used
        Resets soon
        1 week usage
        40%
        """
    )

    precondition(snapshot.fiveHourUsage?.contains("5h usage") == true)
    precondition(snapshot.weeklyUsage?.contains("1 week usage") == true)
    precondition(snapshot.rawSummary?.contains("12 of 50 used") == true)
}

func checkUsageSnapshotParserKeepsContextValues() {
    let snapshot = UsageSnapshotParser.parse(
        visibleText: """
        Daily plugin usage
        16 / 80
        20%
        GPT-5 Thinking
        5h
        33 / 160
        1 week
        42 / 300
        """
    )

    precondition(snapshot.fiveHourUsage?.contains("33 / 160") == true)
    precondition(snapshot.weeklyUsage?.contains("42 / 300") == true)
    precondition(snapshot.rawSummary?.contains("16 / 80") == true)
}

func checkUsageSnapshotParserReadsArticleCards() {
    let snapshot = UsageSnapshotParser.parse(
        visibleText: """
        CARD | 5 小时使用限额 | 2% | 2% | 重置时间：19:30 | 5 小时使用限额 2% 剩余 重置时间：19:30
        CARD | 每周使用限额 | 85% | 85% | 重置时间：2026年5月31日 14:30 | 每周使用限额 85% 剩余 重置时间：2026年5月31日 14:30
        """
    )

    precondition(snapshot.fiveHourUsage == "2% 剩余 · 重置时间：19:30")
    precondition(snapshot.weeklyUsage == "85% 剩余 · 重置时间：2026年5月31日 14:30")
}

func checkUsageSnapshotParserReadsStructuredExtractionCards() {
    let snapshot = UsageSnapshotParser.parse(
        visibleText: """
        USAGE_CARD | kind=5h | remaining=67% | reset=Resets at 19:30
        USAGE_CARD | kind=1w | remaining=91% | reset=重置时间：2026年6月17日 08:00
        """
    )

    precondition(snapshot.fiveHourUsage == "67% 剩余 · Resets at 19:30")
    precondition(snapshot.weeklyUsage == "91% 剩余 · 重置时间：2026年6月17日 08:00")
    precondition(snapshot.rawSummary?.contains("USAGE_CARD") == true)
}

func checkUsageSnapshotParserReadsExtractionDiagnostics() {
    let snapshot = UsageSnapshotParser.parse(
        visibleText: """
        EXTRACTION_DIAGNOSTICS | version=usage-extraction-v2 | structuredCards=2 | articleCards=3 | usageSignalLines=12
        USAGE_CARD | kind=5h | remaining=67% | reset=Resets at 19:30
        USAGE_CARD | kind=1w | remaining=91% | reset=重置时间：2026年6月17日 08:00
        """
    )

    precondition(
        snapshot.extractionDiagnostics == UsageExtractionDiagnostics(
            version: "usage-extraction-v2",
            structuredCardCount: 2,
            articleCardCount: 3,
            usageSignalLineCount: 12
        )
    )
    precondition(snapshot.rawSummary?.contains("EXTRACTION_DIAGNOSTICS") == true)
}

func fixtureText(_ name: String) throws -> String {
    let fixtureURL = Bundle.module.resourceURL!
        .appendingPathComponent(name)
    return try String(contentsOf: fixtureURL, encoding: .utf8)
}

func checkUsageSnapshotParserReadsStructuredFixture() throws {
    let snapshot = UsageSnapshotParser.parse(
        visibleText: try fixtureText("analytics-structured-cards.txt")
    )

    precondition(snapshot.fiveHourUsage == "67% 剩余 · Resets at 19:30")
    precondition(snapshot.weeklyUsage == "91% 剩余 · 重置时间：2026年6月17日 08:00")
    precondition(snapshot.extractionDiagnostics?.structuredCardCount == 2)
}

func checkUsageSnapshotParserMarksOutdatedFixture() throws {
    let snapshot = UsageSnapshotParser.parse(
        visibleText: try fixtureText("analytics-no-usage-cards.txt")
    )

    precondition(!snapshot.hasUsageData)
    precondition(snapshot.lastFailureKind == .parserOutdated)
    precondition(snapshot.extractionDiagnostics?.structuredCardCount == 0)
}

func checkUsageSnapshotParserReadsSubscriptionExpiry() {
    let snapshot = UsageSnapshotParser.parse(
        visibleText: """
        ChatGPT Plus
        你的套餐将于 2026年6月18日 自动续订
        管理
        取消套餐
        如果取消，你仍可在当前计费周期结束前继续使用全部套餐功能。
        """
    )

    precondition(snapshot.subscriptionExpiryText == "2026年6月18日 自动续订")

    let noisySnapshot = UsageSnapshotParser.parse(
        visibleText: "ChatGPT Plus 你的套餐将于 2026年6月18日 自动续订 管理 取消套餐 如果取消，你仍可在当前计费周期结束前继续使用全部套餐功能。"
    )

    precondition(noisySnapshot.subscriptionExpiryText == "2026年6月18日 自动续订")
}

func checkUsageAnalyticsReadinessDetectsLoadingPage() {
    let loadingDiagnostics = """
    URL=https://chatgpt.com/codex/cloud/settings/analytics
    TITLE=Codex
    TEXT=代码 应用 文档 PLUS 设置 常规 环境 代码审查 连接器 分析 数据控制 Codex 分析 7天 1个月 自定义 分组方式： 天 使用情况 代码审查 正在加载使用数据 使用详情 个人使用 额度使用记录
    """

    precondition(UsageAnalyticsReadiness.isStillLoading(loadingDiagnostics))
    precondition(!UsageAnalyticsReadiness.isStillLoading("CARD | 5 小时使用限额 | 42% | 重置时间：19:30"))
}

func checkUsageAnalyticsReadinessDetectsExpectedRoute() {
    precondition(UsageAnalyticsReadiness.isExpectedAnalyticsURL("https://chatgpt.com/codex/cloud/settings/analytics"))
    precondition(UsageAnalyticsReadiness.isExpectedAnalyticsURL("https://chatgpt.com/codex/cloud/settings/analytics?range=7d"))
    precondition(!UsageAnalyticsReadiness.isExpectedAnalyticsURL("https://chatgpt.com/#settings/Billing"))
    precondition(!UsageAnalyticsReadiness.isExpectedAnalyticsURL("about:blank"))
}

func checkUsageAnalyticsReadinessDetectsLoginRequiredPages() {
    precondition(
        UsageAnalyticsReadiness.isLoginRequiredPage(
            urlString: "https://chatgpt.com/auth/login",
            visibleText: ""
        )
    )
    precondition(
        UsageAnalyticsReadiness.isLoginRequiredPage(
            urlString: "https://chatgpt.com/",
            visibleText: "Log in Sign up Continue with Google"
        )
    )
    precondition(
        UsageAnalyticsReadiness.isLoginRequiredPage(
            urlString: "https://chatgpt.com/codex/cloud/settings/analytics",
            visibleText: "请登录后继续"
        )
    )
    precondition(
        !UsageAnalyticsReadiness.isLoginRequiredPage(
            urlString: "https://chatgpt.com/codex/cloud/settings/analytics",
            visibleText: "Codex Analytics 正在加载使用数据"
        )
    )
    precondition(UsageAnalyticsReadiness.isLoginRequiredMessage(UsageAnalyticsReadiness.loginRequiredMessage))
    precondition(!UsageAnalyticsReadiness.isLoginRequiredMessage("Analytics 页面仍在加载使用数据，请稍后重试。"))
}

func checkUsageAnalyticsReadinessClassifiesFailureKinds() {
    precondition(
        UsageAnalyticsReadiness.failureKindForMissingUsage(
            urlString: "https://chatgpt.com/auth/login",
            visibleText: ""
        ) == .loginRequired
    )
    precondition(
        UsageAnalyticsReadiness.failureKindForMissingUsage(
            urlString: "https://chatgpt.com/codex/cloud/settings/analytics",
            visibleText: "Codex Analytics 正在加载使用数据"
        ) == .analyticsLoading
    )
    precondition(
        UsageAnalyticsReadiness.failureKindForMissingUsage(
            urlString: "https://chatgpt.com/",
            visibleText: "ChatGPT"
        ) == .unexpectedPage
    )
    precondition(
        UsageAnalyticsReadiness.failureKindForMissingUsage(
            urlString: "https://chatgpt.com/codex/cloud/settings/analytics",
            visibleText: "Codex Analytics 使用情况 使用详情 个人使用 额度使用记录"
        ) == .parserOutdated
    )
    precondition(UsageReadFailureKind.parserOutdated.displayMessage.contains("页面结构可能变化"))
    precondition(UsageReadFailureKind.timeout.displayMessage.contains("超时"))
}

func checkUsageSnapshotParserIgnoresAnalyticsFilterChrome() {
    let snapshot = UsageSnapshotParser.parse(
        visibleText: """
        Data controls
        Codex Analytics
        7D
        1M
        Custom
        Group by: Day
        Usage
        Usage details
        Personal usage
        Quota usage history
        Remaining quota
        """
    )

    precondition(snapshot.fiveHourUsage == nil)
    precondition(snapshot.weeklyUsage == nil)
    precondition(!snapshot.hasUsageData)
}

func checkUsageSnapshotPreservesPreviousUsageAfterReadFailure() {
    let previous = UsageSnapshot(
        fiveHourUsage: "42% 剩余 · 重置时间：19:30",
        weeklyUsage: "91% 剩余 · 重置时间：2026年6月1日 0:12",
        subscriptionExpiryText: "2026年6月18日 自动续订",
        lastReadAt: Date(timeIntervalSince1970: 1_000)
    )
    let failedRead = UsageSnapshot(
        subscriptionExpiryText: "2026年6月24日 自动续订",
        rawSummary: "正在加载使用数据",
        lastReadAt: Date(timeIntervalSince1970: 2_000),
        lastError: "Analytics 页面仍在加载使用数据，请稍后重试。",
        lastFailureKind: .analyticsLoading
    )

    let merged = previous.preservingUsageData(afterFailedRead: failedRead)

    precondition(merged.fiveHourUsage == previous.fiveHourUsage)
    precondition(merged.weeklyUsage == previous.weeklyUsage)
    precondition(merged.subscriptionExpiryText == "2026年6月24日 自动续订")
    precondition(merged.lastReadAt == Date(timeIntervalSince1970: 2_000))
    precondition(merged.lastError == failedRead.lastError)
    precondition(merged.lastFailureKind == .analyticsLoading)
}

func checkUsageSnapshotPreservesPreviousSubscriptionExpiryWhenBillingReadFails() {
    let previous = UsageSnapshot(
        fiveHourUsage: "42% 剩余 · 重置时间：19:30",
        weeklyUsage: "91% 剩余 · 重置时间：2026年6月1日 0:12",
        subscriptionExpiryText: "2026年6月18日 自动续订"
    )
    let refreshed = UsageSnapshot(
        fiveHourUsage: "76% 剩余 · 重置时间：23:30",
        weeklyUsage: "95% 剩余 · 重置时间：2026年6月8日 0:12"
    )

    let merged = refreshed.preservingSubscriptionExpiry(from: previous)

    precondition(merged.fiveHourUsage == refreshed.fiveHourUsage)
    precondition(merged.weeklyUsage == refreshed.weeklyUsage)
    precondition(merged.subscriptionExpiryText == previous.subscriptionExpiryText)
    precondition(merged.lastError == nil)
}

func checkUsageSnapshotSanitizesAnalyticsFilterChromeUsage() {
    let snapshot = UsageSnapshot(
        weeklyUsage: "Data controls · Codex Analytics · 7D · 1M · Custom · Group by: Day · Usage details",
        rawSummary: "Data controls\nCodex Analytics\n7D\n1M"
    )

    let sanitized = snapshot.removingAnalyticsFilterChromeUsage()

    precondition(sanitized.fiveHourUsage == nil)
    precondition(sanitized.weeklyUsage == nil)
    precondition(!sanitized.hasUsageData)
}

func checkUsageSnapshotFailureKindRoundTrip() throws {
    let snapshot = UsageSnapshot(
        lastReadAt: Date(timeIntervalSince1970: 2_600),
        lastError: UsageReadFailureKind.parserOutdated.displayMessage,
        lastFailureKind: .parserOutdated,
        extractionDiagnostics: UsageExtractionDiagnostics(
            version: "usage-extraction-v2",
            structuredCardCount: 0,
            articleCardCount: 1,
            usageSignalLineCount: 8
        )
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(snapshot)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(UsageSnapshot.self, from: data)

    precondition(decoded.lastFailureKind == .parserOutdated)
    precondition(decoded.lastError == UsageReadFailureKind.parserOutdated.displayMessage)
    precondition(decoded.extractionDiagnostics?.articleCardCount == 1)
}

func checkUsageDiagnosticReportRedactsSensitiveValues() {
    let snapshot = UsageSnapshot(
        rawSummary: "User alice@example.com URL=https://chatgpt.com/auth?code=secret-code&state=secret-state session abcdefghijklmnopqrstuvwxyz1234567890",
        lastReadAt: Date(timeIntervalSince1970: 2_700),
        lastError: "Failed for alice@example.com with token abcdefghijklmnopqrstuvwxyz1234567890",
        lastFailureKind: .parserOutdated,
        extractionDiagnostics: UsageExtractionDiagnostics(
            version: "usage-extraction-v2",
            structuredCardCount: 0,
            articleCardCount: 1,
            usageSignalLineCount: 8
        )
    )

    let report = UsageDiagnosticReport.make(
        version: "1.2.3",
        runMode: "应用模式",
        launchAtLogin: "已启用",
        dataDirectoryPath: "/Users/alice/Library/Application Support/ChatGPTUsageBar",
        queuedRefreshCount: 1,
        refreshingCount: 2,
        accounts: [
            UsageDiagnosticAccount(
                displayName: "Alice Personal",
                loginState: .confirmed,
                snapshot: snapshot
            )
        ]
    )

    precondition(report.contains("Account: #1"))
    precondition(report.contains("Extraction: version=usage-extraction-v2, structured=0, articles=1, signals=8"))
    precondition(!report.contains("Alice Personal"))
    precondition(!report.contains("alice@example.com"))
    precondition(!report.contains("secret-code"))
    precondition(!report.contains("secret-state"))
    precondition(!report.contains("abcdefghijklmnopqrstuvwxyz1234567890"))
    precondition(!report.contains("/Users/alice"))
}

func checkFirstUsageRefreshPolicyStartsAfterDetectedSession() {
    let emptyAccount = AccountProfile.starter(profileDirectory: "Default")
    precondition(FirstUsageRefreshPolicy.shouldRefreshAfterSessionDetected(account: emptyAccount))

    let accountWithUsage = AccountProfile(
        displayName: "已有数据账号",
        subscription: .plus,
        chromeProfileDirectory: "Profile 1",
        usageSnapshot: UsageSnapshot(fiveHourUsage: "42% 剩余 · 重置时间：19:30"),
        loginState: .confirmed
    )
    precondition(!FirstUsageRefreshPolicy.shouldRefreshAfterSessionDetected(account: accountWithUsage))
}

func checkAccountDeletionPlanClearsLocalSession() {
    let accountID = UUID(uuidString: "00000000-0000-0000-0000-000000000041")!
    let plan = AccountDeletionPlan(accountID: accountID)

    precondition(plan.accountID == accountID)
    precondition(plan.clearsLocalWebSession)
    precondition(plan.closesActiveBrowserSurfaces)
}

func checkAccountProfileOrderingMovesSourceBeforeTarget() {
    let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    let accounts = [
        AccountProfile(id: firstID, displayName: "第一个账号", subscription: .plus, chromeProfileDirectory: "Default"),
        AccountProfile(id: secondID, displayName: "第二个账号", subscription: .plus, chromeProfileDirectory: "Profile 1"),
        AccountProfile(id: thirdID, displayName: "第三个账号", subscription: .plus, chromeProfileDirectory: "Profile 2")
    ]

    let reordered = AccountProfileOrdering.moving(
        accounts,
        sourceID: secondID,
        beforeTargetID: firstID
    )

    precondition(reordered.map(\.id) == [secondID, firstID, thirdID])

    let movedToEnd = AccountProfileOrdering.moving(
        accounts,
        sourceID: firstID,
        beforeTargetID: nil
    )

    precondition(movedToEnd.map(\.id) == [secondID, thirdID, firstID])
}

func checkAccountProfileOrderingKeepsPinnedAccountsAtTop() {
    let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    let pinnedID = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
    let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000013")!
    let accounts = [
        AccountProfile(id: firstID, displayName: "普通账号 A", subscription: .plus, chromeProfileDirectory: "Default"),
        AccountProfile(id: pinnedID, displayName: "置顶账号", subscription: .plus, chromeProfileDirectory: "Profile 1", isPinned: true),
        AccountProfile(id: thirdID, displayName: "普通账号 B", subscription: .plus, chromeProfileDirectory: "Profile 2")
    ]

    precondition(AccountProfileOrdering.normalized(accounts).map(\.id) == [pinnedID, firstID, thirdID])

    let movedBeforePinned = AccountProfileOrdering.moving(
        AccountProfileOrdering.normalized(accounts),
        sourceID: thirdID,
        beforeTargetID: pinnedID
    )

    precondition(movedBeforePinned.map(\.id) == [pinnedID, thirdID, firstID])
}

func checkUsageStoreSettingsRoundTrip() throws {
    let selectedID = UUID(uuidString: "00000000-0000-0000-0000-000000000021")!
    let defaultSettings = UsageStoreSettings()
    precondition(defaultSettings.selectedAccountID == nil)
    precondition(!defaultSettings.autoRefresh.isEnabled)
    precondition(defaultSettings.autoRefresh.target == .currentAccount)
    precondition(defaultSettings.autoRefresh.interval == .threeMinutes)
    precondition(defaultSettings.footerQuote.currentIndex == 0)
    precondition(defaultSettings.footerQuote.lastRotationDay == nil)
    precondition(defaultSettings.themePreference == .light)

    let settings = UsageStoreSettings(
        selectedAccountID: selectedID,
        autoRefresh: AutoRefreshSettings(
            isEnabled: true,
            target: .allAccounts,
            interval: .oneMinute
        ),
        footerQuote: FooterQuoteSettings(
            currentIndex: 3,
            lastRotationDay: "2026-05-25"
        ),
        themePreference: .dark
    )

    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(UsageStoreSettings.self, from: data)

    precondition(decoded.selectedAccountID == selectedID)
    precondition(decoded.autoRefresh.isEnabled)
    precondition(decoded.autoRefresh.target == .allAccounts)
    precondition(decoded.autoRefresh.interval == .oneMinute)
    precondition(decoded.footerQuote.currentIndex == 3)
    precondition(decoded.footerQuote.lastRotationDay == "2026-05-25")
    precondition(decoded.themePreference == .dark)
    precondition(AutoRefreshInterval.allCases.map(\.seconds) == [60, 180, 300, 900])
    precondition(AutoRefreshInterval(rawValue: 900)?.seconds == 900)
    precondition(AutoRefreshInterval(rawValue: 900)?.displayName == "15 分钟")

    let legacySettings = """
    {
      "selectedAccountID": "00000000-0000-0000-0000-000000000021",
      "autoRefresh": {
        "isEnabled": true,
        "target": "allAccounts",
        "interval": 300
      }
    }
    """.data(using: .utf8)!

    let decodedLegacySettings = try JSONDecoder().decode(UsageStoreSettings.self, from: legacySettings)
    precondition(decodedLegacySettings.footerQuote == FooterQuoteSettings())
    precondition(decodedLegacySettings.themePreference == .light)
}

func checkAutoRefreshScheduleWaitsBeforeEveryRefresh() {
    precondition(
        AutoRefreshSchedule.delaySecondsBeforeRefresh(
            cycleIndex: 0,
            interval: .oneMinute
        ) == 60
    )
    precondition(
        AutoRefreshSchedule.delaySecondsBeforeRefresh(
            cycleIndex: 1,
            interval: .oneMinute
        ) == 60
    )
}

func checkRefreshQueuePolicyLimitsConcurrentRefreshes() {
    let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000051")!
    let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000052")!
    let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000053")!
    let policy = RefreshQueuePolicy(maxConcurrentRefreshes: 1)

    precondition(
        policy.startableAccountIDs(
            queuedAccountIDs: [firstID, secondID, thirdID],
            refreshingAccountIDs: []
        ) == [firstID]
    )
    precondition(
        policy.startableAccountIDs(
            queuedAccountIDs: [secondID, thirdID],
            refreshingAccountIDs: [firstID]
        ).isEmpty
    )
    precondition(
        policy.startableAccountIDs(
            queuedAccountIDs: [secondID, thirdID],
            refreshingAccountIDs: []
        ) == [secondID]
    )
}

func checkRefreshQueuePolicyDefaultsToThreeConcurrentRefreshes() {
    let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000061")!
    let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000062")!
    let thirdID = UUID(uuidString: "00000000-0000-0000-0000-000000000063")!
    let fourthID = UUID(uuidString: "00000000-0000-0000-0000-000000000064")!
    let policy = RefreshQueuePolicy()

    precondition(policy.maxConcurrentRefreshes == 3)
    precondition(
        policy.startableAccountIDs(
            queuedAccountIDs: [firstID, secondID, thirdID, fourthID],
            refreshingAccountIDs: []
        ) == [firstID, secondID, thirdID]
    )
    precondition(
        policy.startableAccountIDs(
            queuedAccountIDs: [thirdID, fourthID],
            refreshingAccountIDs: [firstID, secondID]
        ) == [thirdID]
    )
}

func checkAppDisplayInfoFormatting() {
    precondition(AppVersionDisplay.text(shortVersion: nil, buildVersion: nil) == "开发版")
    precondition(AppVersionDisplay.text(shortVersion: "", buildVersion: "12") == "开发版")
    precondition(AppVersionDisplay.text(shortVersion: "1.0.0", buildVersion: nil) == "1.0.0")
    precondition(AppVersionDisplay.text(shortVersion: "1.0.0", buildVersion: "") == "1.0.0")
    precondition(AppVersionDisplay.text(shortVersion: "1.0.0", buildVersion: "12") == "1.0.0 (12)")
    precondition(AppRunMode.development.displayName == "开发模式")
    precondition(AppRunMode.appBundle.displayName == "应用模式")
}

func checkAppThemePreference() {
    precondition(AppThemePreference.allCases.map(\.displayName) == ["明亮", "黑暗", "跟随系统"])
    precondition(AppThemePreference.light.effectiveAppearance(systemAppearance: .dark) == .light)
    precondition(AppThemePreference.dark.effectiveAppearance(systemAppearance: .light) == .dark)
    precondition(AppThemePreference.system.effectiveAppearance(systemAppearance: .light) == .light)
    precondition(AppThemePreference.system.effectiveAppearance(systemAppearance: .dark) == .dark)
}

func checkUsageResetScheduleParsesFiveHourResetDates() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let sameDayNow = date(
        year: 2026,
        month: 5,
        day: 25,
        hour: 0,
        minute: 30,
        calendar: calendar
    )
    let sameDayReset = UsageResetSchedule.nextFiveHourResetDate(
        from: "4% 剩余 · 重置时间：1:32",
        now: sameDayNow,
        calendar: calendar
    )
    precondition(
        sameDayReset == date(year: 2026, month: 5, day: 25, hour: 1, minute: 32, calendar: calendar)
    )

    let nextDayNow = date(
        year: 2026,
        month: 5,
        day: 25,
        hour: 2,
        minute: 0,
        calendar: calendar
    )
    let nextDayReset = UsageResetSchedule.nextFiveHourResetDate(
        from: "4% 剩余 · 重置时间：1:32",
        now: nextDayNow,
        calendar: calendar
    )
    precondition(
        nextDayReset == date(year: 2026, month: 5, day: 26, hour: 1, minute: 32, calendar: calendar)
    )

    let fullDateReset = UsageResetSchedule.nextFiveHourResetDate(
        from: "4% 剩余 · 重置时间：2026年5月25日 1:32",
        now: sameDayNow,
        calendar: calendar
    )
    precondition(
        fullDateReset == date(year: 2026, month: 5, day: 25, hour: 1, minute: 32, calendar: calendar)
    )
}

func checkUsageResetScheduleCatchesUpMissedFiveHourReset() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let lastReadAt = date(year: 2026, month: 5, day: 25, hour: 0, minute: 30, calendar: calendar)
    let now = date(year: 2026, month: 5, day: 25, hour: 2, minute: 0, calendar: calendar)

    let decision = UsageResetSchedule.refreshDecision(
        fiveHourUsage: "4% 剩余 · 重置时间：1:32",
        weeklyUsage: nil,
        lastReadAt: lastReadAt,
        now: now,
        calendar: calendar
    )

    precondition(decision.shouldRefreshNow)
    precondition(decision.nextRefreshDate == nil)

    let alreadySeenDecision = UsageResetSchedule.refreshDecision(
        fiveHourUsage: "4% 剩余 · 重置时间：1:32",
        weeklyUsage: nil,
        lastReadAt: date(year: 2026, month: 5, day: 25, hour: 1, minute: 40, calendar: calendar),
        now: now,
        calendar: calendar
    )

    precondition(!alreadySeenDecision.shouldRefreshNow)
    precondition(
        alreadySeenDecision.nextRefreshDate == date(
            year: 2026,
            month: 5,
            day: 26,
            hour: 1,
            minute: 32,
            calendar: calendar
        )
    )
}

func checkUsageResetScheduleHandlesWeeklyFullDateOnly() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = date(year: 2026, month: 6, day: 1, hour: 0, minute: 13, calendar: calendar)
    let weeklyDueDecision = UsageResetSchedule.refreshDecision(
        fiveHourUsage: nil,
        weeklyUsage: "91% 剩余 · 重置 2026年6月1日 0:12",
        lastReadAt: date(year: 2026, month: 5, day: 31, hour: 22, minute: 0, calendar: calendar),
        now: now,
        calendar: calendar
    )

    precondition(weeklyDueDecision.shouldRefreshNow)
    precondition(weeklyDueDecision.nextRefreshDate == nil)

    precondition(
        UsageResetSchedule.nextWeeklyResetDate(
            from: "91% 剩余 · 重置 0:12",
            now: now,
            calendar: calendar
        ) == nil
    )
}

func checkUsageResetScheduleCoalescesDueWindows() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = date(year: 2026, month: 6, day: 1, hour: 0, minute: 13, calendar: calendar)
    let decision = UsageResetSchedule.refreshDecision(
        fiveHourUsage: "42% 剩余 · 重置时间：0:12",
        weeklyUsage: "91% 剩余 · 重置 2026年6月1日 0:12",
        lastReadAt: date(year: 2026, month: 5, day: 31, hour: 22, minute: 0, calendar: calendar),
        now: now,
        calendar: calendar
    )

    precondition(decision.shouldRefreshNow)
    precondition(decision.nextRefreshDate == nil)
}

func checkFooterQuoteCatalogAndRotation() {
    precondition(FooterQuoteCatalog.phrases.count == 34)
    precondition(FooterQuoteCatalog.phrase(at: 0) == "全能的是 AI，省着用的是我")
    precondition(FooterQuoteCatalog.phrase(at: 33) == "把问题想清楚，额度少受苦")
    precondition(FooterQuoteCatalog.phrase(at: 34) == "全能的是 AI，省着用的是我")
    precondition(FooterQuoteCatalog.phrase(at: -1) == "把问题想清楚，额度少受苦")

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let firstDay = date(year: 2026, month: 5, day: 25, hour: 10, minute: 0, calendar: calendar)
    let sameDay = date(year: 2026, month: 5, day: 25, hour: 23, minute: 30, calendar: calendar)
    let secondDay = date(year: 2026, month: 5, day: 26, hour: 0, minute: 1, calendar: calendar)

    let initialized = FooterQuoteRotation.rotateIfNeeded(
        FooterQuoteSettings(currentIndex: 0, lastRotationDay: nil),
        now: firstDay,
        calendar: calendar
    )
    precondition(initialized.currentIndex == 0)
    precondition(initialized.lastRotationDay == "2026-05-25")

    let unchanged = FooterQuoteRotation.rotateIfNeeded(
        initialized,
        now: sameDay,
        calendar: calendar
    )
    precondition(unchanged == initialized)

    let nextDay = FooterQuoteRotation.rotateIfNeeded(
        initialized,
        now: secondDay,
        calendar: calendar
    )
    precondition(nextDay.currentIndex == 1)
    precondition(nextDay.lastRotationDay == "2026-05-26")

    let manual = FooterQuoteRotation.advanceManually(
        nextDay,
        now: secondDay,
        calendar: calendar
    )
    precondition(manual.currentIndex == 2)
    precondition(manual.lastRotationDay == "2026-05-26")
}

func date(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int,
    calendar: Calendar
) -> Date {
    calendar.date(
        from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    )!
}

checkDefaultProfileNames()
try checkAccountRoundTrip()
try checkAccountLoginStateDefaultsAndEligibility()
checkUsageSnapshotParser()
checkUsageSnapshotParserKeepsContextValues()
checkUsageSnapshotParserReadsArticleCards()
checkUsageSnapshotParserReadsStructuredExtractionCards()
checkUsageSnapshotParserReadsExtractionDiagnostics()
try checkUsageSnapshotParserReadsStructuredFixture()
try checkUsageSnapshotParserMarksOutdatedFixture()
checkUsageSnapshotParserReadsSubscriptionExpiry()
checkUsageAnalyticsReadinessDetectsLoadingPage()
checkUsageAnalyticsReadinessDetectsExpectedRoute()
checkUsageAnalyticsReadinessDetectsLoginRequiredPages()
checkUsageAnalyticsReadinessClassifiesFailureKinds()
checkUsageSnapshotParserIgnoresAnalyticsFilterChrome()
checkUsageSnapshotPreservesPreviousUsageAfterReadFailure()
checkUsageSnapshotPreservesPreviousSubscriptionExpiryWhenBillingReadFails()
checkUsageSnapshotSanitizesAnalyticsFilterChromeUsage()
try checkUsageSnapshotFailureKindRoundTrip()
checkUsageDiagnosticReportRedactsSensitiveValues()
checkFirstUsageRefreshPolicyStartsAfterDetectedSession()
checkAccountDeletionPlanClearsLocalSession()
checkAccountProfileOrderingMovesSourceBeforeTarget()
checkAccountProfileOrderingKeepsPinnedAccountsAtTop()
try checkUsageStoreSettingsRoundTrip()
checkAutoRefreshScheduleWaitsBeforeEveryRefresh()
checkRefreshQueuePolicyLimitsConcurrentRefreshes()
checkRefreshQueuePolicyDefaultsToThreeConcurrentRefreshes()
checkAppDisplayInfoFormatting()
checkAppThemePreference()
checkUsageResetScheduleParsesFiveHourResetDates()
checkUsageResetScheduleCatchesUpMissedFiveHourReset()
checkUsageResetScheduleHandlesWeeklyFullDateOnly()
checkUsageResetScheduleCoalescesDueWindows()
checkFooterQuoteCatalogAndRotation()

print("ChatGPTUsageCoreCheck passed")
