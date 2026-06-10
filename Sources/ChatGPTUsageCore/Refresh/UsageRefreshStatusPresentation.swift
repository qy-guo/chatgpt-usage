import Foundation

public enum UsageRefreshStatusTone: Equatable {
    case idle
    case refreshing
    case success
    case failure
}

public struct UsageRefreshStatusPresentation: Equatable {
    public let text: String
    public let tone: UsageRefreshStatusTone
    public let usesShimmer: Bool
    public let usesBorderShimmer: Bool

    public static func resolve(
        refreshPhase: UsageRefreshPhase?,
        isRefreshing: Bool,
        isQueuedForRefresh: Bool,
        isCheckingStoredSession: Bool,
        lastReadText: String?,
        isShowingSuccessPulse: Bool,
        hasFailure: Bool,
        failureText: String? = nil
    ) -> UsageRefreshStatusPresentation {
        if let refreshPhase {
            return UsageRefreshStatusPresentation(
                text: "刷新中 · \(refreshPhase.displayName)",
                tone: .refreshing,
                usesShimmer: true,
                usesBorderShimmer: true
            )
        }

        if isCheckingStoredSession {
            return UsageRefreshStatusPresentation(
                text: "刷新中 · 确认登录状态",
                tone: .refreshing,
                usesShimmer: true,
                usesBorderShimmer: true
            )
        }

        if isQueuedForRefresh {
            return UsageRefreshStatusPresentation(
                text: "刷新中 · 等待刷新队列",
                tone: .refreshing,
                usesShimmer: true,
                usesBorderShimmer: true
            )
        }

        if isRefreshing {
            return UsageRefreshStatusPresentation(
                text: "刷新中 · 正在后台读取 Usage Dashboard",
                tone: .refreshing,
                usesShimmer: true,
                usesBorderShimmer: true
            )
        }

        if hasFailure {
            return UsageRefreshStatusPresentation(
                text: failureText ?? "刷新失败 · 当前显示上次成功数据",
                tone: .failure,
                usesShimmer: false,
                usesBorderShimmer: false
            )
        }

        if isShowingSuccessPulse {
            return UsageRefreshStatusPresentation(
                text: "已刷新 · \(lastReadText ?? "刚刚")",
                tone: .success,
                usesShimmer: false,
                usesBorderShimmer: false
            )
        }

        return UsageRefreshStatusPresentation(
            text: "已更新 · \(lastReadText ?? "尚未读取")",
            tone: .idle,
            usesShimmer: false,
            usesBorderShimmer: false
        )
    }
}
