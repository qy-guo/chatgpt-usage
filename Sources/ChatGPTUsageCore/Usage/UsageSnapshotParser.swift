import Foundation

public enum UsageSnapshotParser {
    public static func parse(visibleText: String, readAt: Date = Date()) -> UsageSnapshot {
        let lines = visibleText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let relevantLines = usageContextLines(from: lines)
        let rawSummary = relevantLines.prefix(48).joined(separator: "\n")
        let extractionDiagnostics = extractionDiagnostics(in: lines)
        let fiveHourUsage = structuredUsageLine(in: lines, matching: isFiveHourKind)
            ?? cardLine(in: lines, matching: isFiveHourLine)
            ?? nearbyUsageLine(in: lines, matching: isFiveHourLine)
        let weeklyUsage = structuredUsageLine(in: lines, matching: isWeeklyKind)
            ?? cardLine(in: lines, matching: isWeeklyLine)
            ?? nearbyUsageLine(in: lines, matching: isWeeklyLine)
        let subscriptionExpiryText = subscriptionExpiryText(in: lines)

        var snapshot = UsageSnapshot(
            fiveHourUsage: fiveHourUsage,
            weeklyUsage: weeklyUsage,
            subscriptionExpiryText: subscriptionExpiryText,
            rawSummary: rawSummary.isEmpty ? nil : rawSummary,
            lastReadAt: readAt,
            lastError: nil,
            extractionDiagnostics: extractionDiagnostics
        ).removingAnalyticsFilterChromeUsage()

        if !snapshot.hasUsageData,
           snapshot.subscriptionExpiryText == nil,
           snapshot.extractionDiagnostics != nil {
            snapshot.lastError = "没有识别到 analytics 用量卡片"
            snapshot.lastFailureKind = .parserOutdated
        } else if snapshot.rawSummary == nil && snapshot.subscriptionExpiryText == nil {
            snapshot.lastError = "没有识别到 analytics 用量文本"
            snapshot.lastFailureKind = .parserOutdated
        }

        return snapshot
    }

    private static func deduplicated(_ lines: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for line in lines {
            let key = line.lowercased()
            guard !seen.contains(key) else {
                continue
            }

            seen.insert(key)
            result.append(line)
        }

        return result
    }

    private static func isUsageLine(_ line: String) -> Bool {
        let value = line.lowercased()
        return isFiveHourLine(line)
            || isWeeklyLine(line)
            || value.contains("usage_card")
            || value.contains("extraction_diagnostics")
            || value.contains("card |")
            || value.contains("daily")
            || value.contains("plugin")
            || value.contains("message")
            || value.contains("messages")
            || value.contains("model")
            || value.contains("usage")
            || value.contains("limit")
            || value.contains("used")
            || value.contains("remaining")
            || value.contains("reset")
            || value.contains("resets")
            || value.contains("allowance")
            || value.contains("quota")
            || value.contains("billing")
            || value.contains("套餐")
            || value.contains("订阅")
            || value.contains("续订")
            || value.contains("renews")
            || value.contains("renew")
            || value.contains("expires")
            || value.contains("expiry")
            || value.contains("%")
    }

    private static func isFiveHourLine(_ line: String) -> Bool {
        let value = line.lowercased()
        return value.contains("5h")
            || value.contains("5 h")
            || value.contains("5-hour")
            || value.contains("5 hour")
            || value.contains("5小时")
            || value.contains("5 小时")
            || value.contains("5 小时使用限额")
            || value.contains("five hour")
            || value.contains("five-hour")
    }

    private static func isWeeklyLine(_ line: String) -> Bool {
        let value = line.lowercased()
        return value.contains("week")
            || value.contains("weekly")
            || value.contains("1w")
            || value.contains("1 w")
            || value.contains("一周")
            || value.contains("每周")
            || value.contains("每周使用限额")
    }

    private static func isFiveHourKind(_ value: String) -> Bool {
        let value = value.lowercased()
        return value == "5h"
            || value == "five_hour"
            || value == "five-hour"
            || value == "5-hour"
    }

    private static func isWeeklyKind(_ value: String) -> Bool {
        let value = value.lowercased()
        return value == "1w"
            || value == "week"
            || value == "weekly"
            || value == "one_week"
            || value == "one-week"
    }

    private static func subscriptionExpiryText(in lines: [String]) -> String? {
        for line in lines {
            if let summary = subscriptionExpirySummary(from: line) {
                return summary
            }
        }

        return nil
    }

    private static func subscriptionExpirySummary(from line: String) -> String? {
        let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else {
            return nil
        }

        if let range = line.range(of: "将于") ?? line.range(of: "将在") {
            guard isChineseSubscriptionExpiryLine(line),
                  !isQuotaResetLine(line) else {
                return nil
            }

            let summary = cleanedSubscriptionExpirySummary(String(line[range.upperBound...]))
            return summary.isEmpty ? nil : summary
        }

        let englishMarkers = [
            "will renew on",
            "renews on",
            "renew on",
            "will end on",
            "ends on",
            "expires on"
        ]

        for marker in englishMarkers {
            guard let range = line.range(of: marker, options: .caseInsensitive) else {
                continue
            }

            guard isEnglishSubscriptionExpiryLine(line),
                  !isQuotaRenewalLine(line) else {
                return nil
            }

            let summary = cleanedSubscriptionExpirySummary(String(line[range.upperBound...]))
            return summary.isEmpty ? nil : summary
        }

        return nil
    }

    private static func isChineseSubscriptionExpiryLine(_ line: String) -> Bool {
        let value = line.lowercased()
        let markers = [
            "套餐",
            "订阅",
            "续订",
            "自动续订",
            "计划",
            "plus",
            "pro",
            "plan",
            "billing"
        ]
        return markers.contains { value.contains($0) }
    }

    private static func isEnglishSubscriptionExpiryLine(_ line: String) -> Bool {
        let value = line.lowercased()
        let markers = [
            "subscription",
            "plan",
            "billing",
            "membership",
            "plus",
            "pro",
            "team",
            "enterprise"
        ]
        return markers.contains { value.contains($0) }
    }

    private static func isQuotaResetLine(_ line: String) -> Bool {
        let value = line.lowercased()
        let hasResetSignal = value.contains("重置") || value.contains("reset")
        let quotaMarkers = [
            "使用限额",
            "额度",
            "余额",
            "usage",
            "limit",
            "quota",
            "allowance",
            "remaining"
        ]
        return hasResetSignal && quotaMarkers.contains { value.contains($0) }
    }

    private static func isQuotaRenewalLine(_ line: String) -> Bool {
        let value = line.lowercased()
        let quotaMarkers = [
            "使用限额",
            "额度",
            "余额",
            "usage",
            "limit",
            "quota",
            "allowance",
            "remaining",
            "credit",
            "credits"
        ]
        return quotaMarkers.contains { value.contains($0) }
    }

    private static func cleanedSubscriptionExpirySummary(_ value: String) -> String {
        var summary = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "。.;；"))

        let stopMarkers = [
            " 管理",
            " 取消套餐",
            " 如果取消",
            " Manage",
            " Cancel",
            " Change plan"
        ]

        for marker in stopMarkers {
            if let range = summary.range(of: marker, options: .caseInsensitive) {
                summary = String(summary[..<range.lowerBound])
            }
        }

        return summary
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "。.;；"))
    }

    private static func cardLine(
        in lines: [String],
        matching predicate: (String) -> Bool
    ) -> String? {
        guard let line = lines.first(where: { line in
            line.localizedCaseInsensitiveContains("CARD |") && predicate(line)
        }) else {
            return nil
        }

        return summarizeCardLine(line)
    }

    private static func summarizeCardLine(_ line: String) -> String {
        let parts = line
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "CARD" }

        guard !parts.isEmpty else {
            return line.replacingOccurrences(of: "CARD | ", with: "")
        }

        let title = parts[safe: 0]
        let percent = parts.first { $0.range(of: #"^[0-9]+(?:\.[0-9]+)?%$"#, options: .regularExpression) != nil }
        let reset = parts.first { $0.localizedCaseInsensitiveContains("重置") || $0.localizedCaseInsensitiveContains("reset") }

        var summaryParts: [String] = []
        if let percent {
            summaryParts.append("\(percent) 剩余")
        }
        if let reset {
            summaryParts.append(reset)
        }

        if !summaryParts.isEmpty {
            return summaryParts.joined(separator: " · ")
        }

        return parts.dropFirst(title == nil ? 0 : 1).joined(separator: " · ")
    }

    private static func structuredUsageLine(
        in lines: [String],
        matching kindPredicate: (String) -> Bool
    ) -> String? {
        for line in lines where line.localizedCaseInsensitiveContains("USAGE_CARD") {
            let fields = structuredFields(from: line)
            let kind = fields["kind"] ?? fields["window"] ?? ""
            guard kindPredicate(kind) else {
                continue
            }

            let remaining = fields["remaining"] ?? fields["percent"]
            let reset = fields["reset"]

            var summaryParts: [String] = []
            if let remaining, !remaining.isEmpty {
                summaryParts.append(remainingSummary(from: remaining))
            }
            if let reset, !reset.isEmpty {
                summaryParts.append(reset)
            }

            if !summaryParts.isEmpty {
                return summaryParts.joined(separator: " · ")
            }
        }

        return nil
    }

    private static func structuredFields(from line: String) -> [String: String] {
        let parts = line
            .components(separatedBy: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.localizedCaseInsensitiveCompare("USAGE_CARD") != .orderedSame }

        var fields: [String: String] = [:]
        for part in parts {
            guard let separator = part.firstIndex(of: "=") else {
                continue
            }

            let key = part[..<separator]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let value = part[part.index(after: separator)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            fields[key] = value
        }

        return fields
    }

    private static func extractionDiagnostics(in lines: [String]) -> UsageExtractionDiagnostics? {
        guard let line = lines.first(where: { $0.localizedCaseInsensitiveContains("EXTRACTION_DIAGNOSTICS") }) else {
            return nil
        }

        let fields = structuredFields(from: line)
        return UsageExtractionDiagnostics(
            version: fields["version"],
            structuredCardCount: intValue(fields["structuredcards"] ?? fields["structured_cards"]),
            articleCardCount: intValue(fields["articlecards"] ?? fields["article_cards"]),
            usageSignalLineCount: intValue(fields["usagesignallines"] ?? fields["usage_signal_lines"])
        )
    }

    private static func intValue(_ value: String?) -> Int {
        guard let value else {
            return 0
        }

        return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }

    private static func remainingSummary(from value: String) -> String {
        if value.localizedCaseInsensitiveContains("剩余")
            || value.localizedCaseInsensitiveContains("remaining") {
            return value
        }

        return "\(value) 剩余"
    }

    private static func usageContextLines(from lines: [String]) -> [String] {
        var selectedIndices = Set<Int>()

        for (index, line) in lines.enumerated() where isUsageLine(line) {
            let lowerBound = max(0, index - 4)
            let upperBound = min(lines.count - 1, index + 10)

            for nearbyIndex in lowerBound...upperBound {
                selectedIndices.insert(nearbyIndex)
            }
        }

        let selectedLines = selectedIndices
            .sorted()
            .map { lines[$0] }
            .filter { !isChromeNoiseLine($0) }

        return deduplicated(selectedLines)
    }

    private static func isChromeNoiseLine(_ line: String) -> Bool {
        let value = line.lowercased()
        let noise = [
            "chatgpt",
            "new chat",
            "settings",
            "log out",
            "terms",
            "privacy",
            "upgrade",
            "download",
            "keyboard shortcuts"
        ]

        return noise.contains(value)
    }

    private static func nearbyUsageLine(
        in lines: [String],
        matching predicate: (String) -> Bool
    ) -> String? {
        guard let index = lines.firstIndex(where: predicate) else {
            return nil
        }

        let lowerBound = max(0, index - 2)
        let upperBound = min(lines.count, index + 9)
        let window = lines[lowerBound..<upperBound].filter { !isChromeNoiseLine($0) }
        let compactWindow = deduplicated(Array(window)).prefix(10)
        return compactWindow.joined(separator: " · ")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
