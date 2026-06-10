import Foundation

public enum AccountSessionVerification {
    public static func canTrustCookieSession(
        cookieCount: Int,
        urlString: String?,
        visibleText: String
    ) -> Bool {
        guard cookieCount > 0 else {
            return false
        }

        if UsageAnalyticsReadiness.isLoginRequiredPage(urlString: urlString, visibleText: visibleText) {
            return false
        }

        if UsageAnalyticsReadiness.isExpectedAnalyticsURL(urlString) {
            return hasAnalyticsPageSignal(visibleText)
        }

        guard let urlString,
              let url = URL(string: urlString),
              url.host?.lowercased() == "chatgpt.com" else {
            return false
        }

        let path = url.path.lowercased()
        if path.contains("/auth") || path.contains("/login") {
            return false
        }

        return hasAuthenticatedChatSignal(visibleText)
    }

    private static func hasAnalyticsPageSignal(_ visibleText: String) -> Bool {
        let normalized = normalize(visibleText)
        let markers = [
            "codex analytics",
            "usage details",
            "personal usage",
            "quota usage history",
            "codex 分析",
            "使用详情",
            "个人使用",
            "额度使用记录"
        ]
        return markers.contains { normalized.contains($0) }
    }

    private static func hasAuthenticatedChatSignal(_ visibleText: String) -> Bool {
        let normalized = normalize(visibleText)
        let markers = [
            "new chat",
            "explore gpts",
            "settings",
            "log out",
            "新聊天",
            "探索 gpts",
            "设置",
            "退出登录"
        ]
        return markers.contains { normalized.contains($0) }
    }

    private static func normalize(_ value: String) -> String {
        value
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
