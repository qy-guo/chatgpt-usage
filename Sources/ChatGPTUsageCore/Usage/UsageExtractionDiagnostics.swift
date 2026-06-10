import Foundation

public struct UsageExtractionDiagnostics: Codable, Equatable {
    public var version: String?
    public var structuredCardCount: Int
    public var articleCardCount: Int
    public var usageSignalLineCount: Int

    public init(
        version: String? = nil,
        structuredCardCount: Int = 0,
        articleCardCount: Int = 0,
        usageSignalLineCount: Int = 0
    ) {
        self.version = version
        self.structuredCardCount = max(0, structuredCardCount)
        self.articleCardCount = max(0, articleCardCount)
        self.usageSignalLineCount = max(0, usageSignalLineCount)
    }

    public var compactSummary: String {
        [
            "version=\(version ?? "unknown")",
            "structured=\(structuredCardCount)",
            "articles=\(articleCardCount)",
            "signals=\(usageSignalLineCount)"
        ].joined(separator: ", ")
    }
}
