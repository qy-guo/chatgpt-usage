import Foundation

public struct UsageDiagnosticAccount: Equatable {
    public var displayName: String
    public var loginState: AccountLoginState
    public var snapshot: UsageSnapshot

    public init(
        displayName: String,
        loginState: AccountLoginState,
        snapshot: UsageSnapshot
    ) {
        self.displayName = displayName
        self.loginState = loginState
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
            let rawSummary = snapshot.rawSummary.map { String($0.prefix(700)) } ?? "none"

            return [
                "Account: #\(index + 1)",
                "Login state: \(account.loginState.rawValue)",
                "Last read: \(lastReadAt)",
                "Failure kind: \(failureKind)",
                "Extraction: \(extraction)",
                "Last error: \(lastError)",
                "Summary: \(rawSummary.replacingOccurrences(of: "\n", with: " / "))"
            ].joined(separator: "\n")
        }
        .joined(separator: "\n---\n")

        let report = [
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
}
