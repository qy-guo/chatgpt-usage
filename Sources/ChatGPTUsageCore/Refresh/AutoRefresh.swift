import Foundation

public enum AutoRefreshTarget: String, CaseIterable, Codable, Identifiable {
    case currentAccount
    case allAccounts

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .currentAccount:
            "当前"
        case .allAccounts:
            "全部"
        }
    }
}

public enum AutoRefreshInterval: Int, CaseIterable, Codable, Identifiable {
    case oneMinute = 60
    case threeMinutes = 180
    case fiveMinutes = 300
    case fifteenMinutes = 900

    public var id: Int { rawValue }
    public var seconds: Int { rawValue }

    public var displayName: String {
        switch self {
        case .oneMinute:
            "1 分钟"
        case .threeMinutes:
            "3 分钟"
        case .fiveMinutes:
            "5 分钟"
        case .fifteenMinutes:
            "15 分钟"
        }
    }
}

public struct AutoRefreshSettings: Codable, Equatable {
    public var isEnabled: Bool
    public var target: AutoRefreshTarget
    public var interval: AutoRefreshInterval

    public init(
        isEnabled: Bool = false,
        target: AutoRefreshTarget = .currentAccount,
        interval: AutoRefreshInterval = .threeMinutes
    ) {
        self.isEnabled = isEnabled
        self.target = target
        self.interval = interval
    }
}

public enum AutoRefreshSchedule {
    public static func delaySecondsBeforeRefresh(
        cycleIndex: Int,
        interval: AutoRefreshInterval
    ) -> Int {
        interval.seconds
    }
}

public enum UsageAnalyticsReadiness {
    public static let loginRequiredMessage = "登录状态已失效，请重新登录。"

    public static func isExpectedAnalyticsURL(_ urlString: String?) -> Bool {
        guard let urlString,
              let url = URL(string: urlString),
              url.host?.lowercased() == "chatgpt.com" else {
            return false
        }

        return url.path == "/codex/cloud/settings/analytics"
    }

    public static func isLoginRequiredPage(urlString: String?, visibleText: String) -> Bool {
        if let urlString,
           let url = URL(string: urlString),
           url.host?.lowercased() == "chatgpt.com" {
            let path = url.path.lowercased()
            if path.contains("/auth") || path.contains("/login") {
                return true
            }
        }

        let normalized = visibleText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else {
            return false
        }

        let pageURLMarkers = [
            "url=https://chatgpt.com/auth",
            "url=https://chatgpt.com/login"
        ]
        if pageURLMarkers.contains(where: { normalized.contains($0) }) {
            return true
        }

        let loginMarkers = [
            "log in sign up",
            "log in",
            "sign in",
            "continue with google",
            "continue with microsoft",
            "请登录",
            "登录后继续",
            "登录以继续"
        ]
        return loginMarkers.contains { normalized.contains($0) }
    }

    public static func isLoginRequiredMessage(_ message: String?) -> Bool {
        message == loginRequiredMessage
    }

    public static func isStillLoading(_ visibleText: String) -> Bool {
        let normalized = visibleText
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else {
            return false
        }

        let loadingMarkers = [
            "正在加载使用数据",
            "loading usage data",
            "loading usage",
            "loading data"
        ]

        return loadingMarkers.contains { normalized.contains($0) }
    }
}
