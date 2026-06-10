import Foundation

public struct UsageStoreSettings: Codable, Equatable {
    public var selectedAccountID: UUID?
    public var autoRefresh: AutoRefreshSettings
    public var footerQuote: FooterQuoteSettings
    public var themePreference: AppThemePreference
    public var refreshEffects: RefreshEffectSettings

    public init(
        selectedAccountID: UUID? = nil,
        autoRefresh: AutoRefreshSettings = AutoRefreshSettings(),
        footerQuote: FooterQuoteSettings = FooterQuoteSettings(),
        themePreference: AppThemePreference = .light,
        refreshEffects: RefreshEffectSettings = RefreshEffectSettings()
    ) {
        self.selectedAccountID = selectedAccountID
        self.autoRefresh = autoRefresh
        self.footerQuote = footerQuote
        self.themePreference = themePreference
        self.refreshEffects = refreshEffects
    }

    private enum CodingKeys: String, CodingKey {
        case selectedAccountID
        case autoRefresh
        case footerQuote
        case themePreference
        case refreshEffects
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
        refreshEffects = try container.decodeIfPresent(RefreshEffectSettings.self, forKey: .refreshEffects)
            ?? RefreshEffectSettings()
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encodeIfPresent(selectedAccountID, forKey: .selectedAccountID)
        try container.encode(autoRefresh, forKey: .autoRefresh)
        try container.encode(footerQuote, forKey: .footerQuote)
        try container.encode(themePreference, forKey: .themePreference)
        try container.encode(refreshEffects, forKey: .refreshEffects)
    }
}
