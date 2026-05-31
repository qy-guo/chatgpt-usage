import Foundation

public struct AccountProfile: Identifiable, Codable, Equatable {
    public var id: UUID
    public var displayName: String
    public var accountHint: String
    public var subscription: SubscriptionPlan
    public var chromeProfileDirectory: String
    public var usageSnapshot: UsageSnapshot?
    public var isPinned: Bool
    public var loginState: AccountLoginState
    public var lastSessionCheckAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        displayName: String,
        accountHint: String = "",
        subscription: SubscriptionPlan,
        chromeProfileDirectory: String,
        usageSnapshot: UsageSnapshot? = nil,
        isPinned: Bool = false,
        loginState: AccountLoginState = .notLoggedIn,
        lastSessionCheckAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.accountHint = accountHint
        self.subscription = subscription
        self.chromeProfileDirectory = chromeProfileDirectory
        self.usageSnapshot = (usageSnapshot ?? .empty).removingAnalyticsFilterChromeUsage()
        self.isPinned = isPinned
        self.loginState = loginState
        self.lastSessionCheckAt = lastSessionCheckAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var resolvedUsageSnapshot: UsageSnapshot {
        usageSnapshot ?? .empty
    }

    public static func starter(profileDirectory: String, now: Date = Date()) -> AccountProfile {
        AccountProfile(
            displayName: "个人账号",
            accountHint: "",
            subscription: .plus,
            chromeProfileDirectory: profileDirectory,
            createdAt: now,
            updatedAt: now
        )
    }

    public static func defaultChromeProfileName(forAccountIndex index: Int) -> String {
        index == 0 ? "Default" : "Profile \(index)"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case accountHint
        case subscription
        case chromeProfileDirectory
        case usageSnapshot
        case isPinned
        case loginState
        case lastSessionCheckAt
        case createdAt
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? "个人账号"
        accountHint = try container.decodeIfPresent(String.self, forKey: .accountHint) ?? ""
        subscription = try container.decodeIfPresent(SubscriptionPlan.self, forKey: .subscription) ?? .plus
        chromeProfileDirectory = try container.decodeIfPresent(String.self, forKey: .chromeProfileDirectory) ?? ""
        let decodedUsageSnapshot = (try container.decodeIfPresent(UsageSnapshot.self, forKey: .usageSnapshot) ?? .empty)
            .removingAnalyticsFilterChromeUsage()
        usageSnapshot = decodedUsageSnapshot
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        loginState = try container.decodeIfPresent(AccountLoginState.self, forKey: .loginState)
            ?? (decodedUsageSnapshot.hasUsageData ? .confirmed : .notLoggedIn)
        lastSessionCheckAt = try container.decodeIfPresent(Date.self, forKey: .lastSessionCheckAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(accountHint, forKey: .accountHint)
        try container.encode(subscription, forKey: .subscription)
        try container.encode(chromeProfileDirectory, forKey: .chromeProfileDirectory)
        try container.encode(resolvedUsageSnapshot, forKey: .usageSnapshot)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(loginState, forKey: .loginState)
        try container.encodeIfPresent(lastSessionCheckAt, forKey: .lastSessionCheckAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

public enum AccountProfileOrdering {
    public static func normalized(_ accounts: [AccountProfile]) -> [AccountProfile] {
        accounts.filter(\.isPinned) + accounts.filter { !$0.isPinned }
    }

    public static func moving(
        _ accounts: [AccountProfile],
        sourceID: UUID,
        beforeTargetID targetID: UUID?
    ) -> [AccountProfile] {
        let normalizedAccounts = normalized(accounts)

        guard let sourceIndex = normalizedAccounts.firstIndex(where: { $0.id == sourceID }) else {
            return accounts
        }

        var reorderedAccounts = normalizedAccounts
        let movedAccount = reorderedAccounts.remove(at: sourceIndex)
        let firstUnpinnedIndex = reorderedAccounts.firstIndex { !$0.isPinned } ?? reorderedAccounts.count

        guard let targetID,
              sourceID != targetID,
              let rawInsertionIndex = reorderedAccounts.firstIndex(where: { $0.id == targetID }) else {
            reorderedAccounts.append(movedAccount)
            return normalized(reorderedAccounts)
        }

        let insertionIndex = movedAccount.isPinned
            ? min(rawInsertionIndex, firstUnpinnedIndex)
            : max(rawInsertionIndex, firstUnpinnedIndex)
        reorderedAccounts.insert(movedAccount, at: insertionIndex)
        return normalized(reorderedAccounts)
    }
}
