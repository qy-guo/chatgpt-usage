import Foundation

public struct FooterQuoteSettings: Codable, Equatable {
    public var currentIndex: Int
    public var lastRotationDay: String?

    public init(
        currentIndex: Int = 0,
        lastRotationDay: String? = nil
    ) {
        self.currentIndex = currentIndex
        self.lastRotationDay = lastRotationDay
    }
}

public enum FooterQuoteCatalog {
    public static let phrases = [
        "全能的是 AI，省着用的是我",
        "今天也在理性消耗额度",
        "人类负责判断，AI 负责燃烧额度",
        "代码还没跑，用量先紧张了",
        "问之前深呼吸，额度会感谢你",
        "让 AI 想一会儿，让额度慢点掉",
        "我的脑子在缓存，额度在下降",
        "不怕 AI 太强，就怕额度太短",
        "珍惜额度，尊重最后的调参权",
        "全栈已死，额度当立",
        "AI 负责全能，我负责心疼",
        "少问一句是一句，多想一秒是一秒",
        "今日份智慧，由额度赞助",
        "向 AI 提问，向余额低头",
        "别急着问，先假装会一点",
        "提示词很短，账单很真实",
        "今天的聪明额度有限",
        "别问太猛，额度会累",
        "需求无限，额度有限",
        "先想三秒，再请外援",
        "写代码靠灵感，省用量靠自觉",
        "全能助手，限量供应",
        "AI 很强，我很节俭",
        "能本地想的，先别上模型",
        "每次提问，都是一次投资",
        "今日额度，请谨慎施法",
        "先读报错，再问 AI",
        "我和 AI 之间，只差一点额度",
        "代码可以重构，额度不能撤回",
        "别急，先让人类试试",
        "需求还在变，额度先别动",
        "一问一答，皆是预算",
        "能少问一轮，就少心疼一轮",
        "把问题想清楚，额度少受苦"
    ]

    public static func phrase(at index: Int) -> String {
        guard !phrases.isEmpty else {
            return ""
        }

        return phrases[normalizedIndex(index)]
    }

    public static func normalizedIndex(_ index: Int) -> Int {
        guard !phrases.isEmpty else {
            return 0
        }

        let remainder = index % phrases.count
        return remainder >= 0 ? remainder : remainder + phrases.count
    }

    public static func index(after index: Int) -> Int {
        normalizedIndex(index + 1)
    }
}

public enum FooterQuoteRotation {
    public static func rotateIfNeeded(
        _ settings: FooterQuoteSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FooterQuoteSettings {
        let today = dayIdentifier(for: now, calendar: calendar)
        var result = normalized(settings)

        guard let lastRotationDay = result.lastRotationDay else {
            result.lastRotationDay = today
            return result
        }

        guard lastRotationDay != today else {
            return result
        }

        result.currentIndex = FooterQuoteCatalog.index(after: result.currentIndex)
        result.lastRotationDay = today
        return result
    }

    public static func advanceManually(
        _ settings: FooterQuoteSettings,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FooterQuoteSettings {
        var result = normalized(settings)
        result.currentIndex = FooterQuoteCatalog.index(after: result.currentIndex)
        result.lastRotationDay = dayIdentifier(for: now, calendar: calendar)
        return result
    }

    private static func normalized(_ settings: FooterQuoteSettings) -> FooterQuoteSettings {
        FooterQuoteSettings(
            currentIndex: FooterQuoteCatalog.normalizedIndex(settings.currentIndex),
            lastRotationDay: settings.lastRotationDay
        )
    }

    private static func dayIdentifier(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
