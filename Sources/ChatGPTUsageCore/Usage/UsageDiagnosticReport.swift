import Foundation

public struct UsageDiagnosticAccount: Equatable {
    public var displayName: String
    public var loginState: AccountLoginState
    public var refreshPhase: UsageRefreshPhase?
    public var snapshot: UsageSnapshot

    public init(
        displayName: String,
        loginState: AccountLoginState,
        refreshPhase: UsageRefreshPhase? = nil,
        snapshot: UsageSnapshot
    ) {
        self.displayName = displayName
        self.loginState = loginState
        self.refreshPhase = refreshPhase
        self.snapshot = snapshot
    }
}

public enum UsageDiagnosticRedactor {
    public static func redact(_ value: String) -> String {
        var redacted = value
        redacted = redacted.replacingOccurrences(
            of: #"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
            with: "[redacted-email]",
            options: .regularExpression
        )
        redacted = redacted.replacingOccurrences(
            of: #"(?i)\b(access_token|id_token|refresh_token|token|code|state|session|login_hint)=([^&\s]+)"#,
            with: "$1=[redacted]",
            options: .regularExpression
        )
        redacted = redacted.replacingOccurrences(
            of: #"/Users/[^/\s]+"#,
            with: "/Users/[redacted-user]",
            options: .regularExpression
        )
        redacted = redacted.replacingOccurrences(
            of: #"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b"#,
            with: "[redacted-id]",
            options: .regularExpression
        )
        redacted = redacted.replacingOccurrences(
            of: #"(?<![A-Za-z0-9])[A-Za-z0-9_-]{32,}(?![A-Za-z0-9])"#,
            with: "[redacted-token]",
            options: .regularExpression
        )
        return redacted
    }
}

public enum UsageDiagnosticReport {
    public static func make(
        version: String,
        runMode: String,
        launchAtLogin: String,
        dataDirectoryPath: String,
        queuedRefreshCount: Int,
        refreshingCount: Int,
        accounts: [UsageDiagnosticAccount]
    ) -> String {
        let dateFormatter = ISO8601DateFormatter()
        let accountDiagnostics = accounts.enumerated().map { index, account in
            let snapshot = account.snapshot
            let lastReadAt = snapshot.lastReadAt.map { dateFormatter.string(from: $0) } ?? "never"
            let failureKind = snapshot.lastFailureKind?.rawValue ?? "none"
            let lastError = snapshot.lastError ?? "none"
            let extraction = snapshot.extractionDiagnostics?.compactSummary ?? "none"
            let refreshPhase = account.refreshPhase?.diagnosticLabel ?? "idle"
            let suggestedAction = suggestedAction(for: snapshot.lastFailureKind)
            let rawSummary = snapshot.rawSummary.map { String($0.prefix(700)) } ?? "none"

            return [
                "Account: #\(index + 1)",
                "Login state: \(account.loginState.rawValue)",
                "Refresh phase: \(refreshPhase)",
                "Last read: \(lastReadAt)",
                "Failure kind: \(failureKind)",
                "Suggested action: \(suggestedAction)",
                "Extraction: \(extraction)",
                "Last error: \(lastError)",
                "Summary: \(rawSummary.replacingOccurrences(of: "\n", with: " / "))"
            ].joined(separator: "\n")
        }
        .joined(separator: "\n---\n")

        let report = [
            "Diagnostic report: ChatGPT Usage Bar",
            "Privacy: sensitive values are redacted before copying.",
            "",
            "Version: \(version)",
            "Run mode: \(runMode)",
            "Launch at login: \(launchAtLogin)",
            "Accounts: \(accounts.count)",
            "Data: \(dataDirectoryPath)",
            "Queued refreshes: \(queuedRefreshCount)",
            "Refreshing: \(refreshingCount)",
            "",
            accountDiagnostics
        ].joined(separator: "\n")

        return UsageDiagnosticRedactor.redact(report)
    }

    private static func suggestedAction(for failureKind: UsageReadFailureKind?) -> String {
        switch failureKind {
        case .loginRequired:
            "重新打开登录窗口完成登录，然后再次刷新。"
        case .analyticsLoading:
            "稍后再次刷新；如果持续卡住，请打开登录窗口确认 Analytics 页面是否能正常加载。"
        case .unexpectedPage:
            "再次刷新以回到 Analytics 页面；如果仍跳转异常，请打开登录窗口确认当前页面。"
        case .parserOutdated:
            "复制本诊断报告反馈，官方页面结构可能需要适配。"
        case .timeout:
            "检查网络后重试；如果多次超时，请打开登录窗口确认页面加载状态。"
        case .webKitEvaluation:
            "重新打开登录窗口确认网页状态，必要时重启应用后再刷新。"
        case nil:
            "暂无异常；如数据不符合预期，可再次刷新或复制本报告排查。"
        }
    }
}
