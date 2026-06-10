import Foundation

public struct RefreshQueuePolicy: Equatable {
    public var maxConcurrentRefreshes: Int

    public init(maxConcurrentRefreshes: Int = 3) {
        self.maxConcurrentRefreshes = max(1, maxConcurrentRefreshes)
    }

    public func startableAccountIDs(
        queuedAccountIDs: [UUID],
        refreshingAccountIDs: Set<UUID>
    ) -> [UUID] {
        let availableSlots = maxConcurrentRefreshes - refreshingAccountIDs.count
        guard availableSlots > 0 else {
            return []
        }

        return queuedAccountIDs
            .filter { !refreshingAccountIDs.contains($0) }
            .prefix(availableSlots)
            .map(\.self)
    }
}
