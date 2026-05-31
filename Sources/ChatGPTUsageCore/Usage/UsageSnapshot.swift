import Foundation

public struct UsageSnapshot: Codable, Equatable {
    public var fiveHourUsage: String?
    public var weeklyUsage: String?
    public var subscriptionExpiryText: String?
    public var rawSummary: String?
    public var lastReadAt: Date?
    public var lastError: String?

    public init(
        fiveHourUsage: String? = nil,
        weeklyUsage: String? = nil,
        subscriptionExpiryText: String? = nil,
        rawSummary: String? = nil,
        lastReadAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.fiveHourUsage = fiveHourUsage
        self.weeklyUsage = weeklyUsage
        self.subscriptionExpiryText = subscriptionExpiryText
        self.rawSummary = rawSummary
        self.lastReadAt = lastReadAt
        self.lastError = lastError
    }

    public static var empty: UsageSnapshot {
        UsageSnapshot()
    }

    public var hasUsageData: Bool {
        fiveHourUsage != nil || weeklyUsage != nil
    }

    public func preservingUsageData(afterFailedRead failedRead: UsageSnapshot) -> UsageSnapshot {
        let failedRead = failedRead.removingAnalyticsFilterChromeUsage()
        guard !failedRead.hasUsageData else {
            return failedRead
        }

        var merged = removingAnalyticsFilterChromeUsage()
        if let subscriptionExpiryText = failedRead.subscriptionExpiryText {
            merged.subscriptionExpiryText = subscriptionExpiryText
        }
        if let rawSummary = failedRead.rawSummary {
            merged.rawSummary = rawSummary
        }
        merged.lastReadAt = failedRead.lastReadAt ?? merged.lastReadAt
        merged.lastError = failedRead.lastError
        return merged
    }

    public func removingAnalyticsFilterChromeUsage() -> UsageSnapshot {
        var sanitized = self
        if Self.isAnalyticsFilterChromeUsage(fiveHourUsage) {
            sanitized.fiveHourUsage = nil
        }
        if Self.isAnalyticsFilterChromeUsage(weeklyUsage) {
            sanitized.weeklyUsage = nil
        }
        return sanitized
    }

    private static func isAnalyticsFilterChromeUsage(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        let normalized = value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else {
            return false
        }

        let hasRealUsageSignal = normalized.range(
            of: #"(\d+(?:\.\d+)?\s*%)|(\d+\s*/\s*\d+)|剩余|重置|remaining|reset|used"#,
            options: .regularExpression
        ) != nil

        guard !hasRealUsageSignal else {
            return false
        }

        let hasAnalyticsChrome = normalized.contains("codex analytics")
            || normalized.contains("data controls")
            || normalized.contains("数据控制")
            || normalized.contains("分组方式")
            || normalized.contains("group by")
        let hasRangeFilter = normalized.contains("7d")
            || normalized.contains("7天")
            || normalized.contains("1m")
            || normalized.contains("1个月")
            || normalized.contains("custom")
            || normalized.contains("自定义")

        return hasAnalyticsChrome && hasRangeFilter
    }
}
