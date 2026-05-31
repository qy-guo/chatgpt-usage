import Foundation

public struct UsageStoreSettings: Codable, Equatable {
    public var selectedAccountID: UUID?
    public var autoRefresh: AutoRefreshSettings
    public var footerQuote: FooterQuoteSettings
    public var themePreference: AppThemePreference

    public init(
        selectedAccountID: UUID? = nil,
        autoRefresh: AutoRefreshSettings = AutoRefreshSettings(),
        footerQuote: FooterQuoteSettings = FooterQuoteSettings(),
        themePreference: AppThemePreference = .light
    ) {
        self.selectedAccountID = selectedAccountID
        self.autoRefresh = autoRefresh
        self.footerQuote = footerQuote
        self.themePreference = themePreference
    }

    private enum CodingKeys: String, CodingKey {
        case selectedAccountID
        case autoRefresh
        case footerQuote
        case themePreference
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        selectedAccountID = try container.decodeIfPresent(UUID.self, forKey: .selectedAccountID)
        autoRefresh = try container.decodeIfPresent(AutoRefreshSettings.self, forKey: .autoRefresh)
            ?? AutoRefreshSettings()
        footerQuote = try container.decodeIfPresent(FooterQuoteSettings.self, forKey: .footerQuote)
            ?? FooterQuoteSettings()
        themePreference = try container.decodeIfPresent(AppThemePreference.self, forKey: .themePreference)
            ?? .light
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(selectedAccountID, forKey: .selectedAccountID)
        try container.encode(autoRefresh, forKey: .autoRefresh)
        try container.encode(footerQuote, forKey: .footerQuote)
        try container.encode(themePreference, forKey: .themePreference)
    }
}
