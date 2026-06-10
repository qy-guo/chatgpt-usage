import Foundation

public struct AccountDeletionPlan: Equatable {
    public var accountID: UUID
    public var clearsLocalWebSession: Bool
    public var closesActiveBrowserSurfaces: Bool

    public init(
        accountID: UUID,
        clearsLocalWebSession: Bool = true,
        closesActiveBrowserSurfaces: Bool = true
    ) {
        self.accountID = accountID
        self.clearsLocalWebSession = clearsLocalWebSession
        self.closesActiveBrowserSurfaces = closesActiveBrowserSurfaces
    }
}

public enum FirstUsageRefreshPolicy {
    public static func shouldRefreshAfterSessionDetected(account: AccountProfile) -> Bool {
        !account.resolvedUsageSnapshot.hasUsageData
    }
}
