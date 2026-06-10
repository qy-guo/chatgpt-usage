import Foundation

public enum RefreshTrigger: String, Codable, Equatable {
    case manual
    case automatic
    case reset
    case sessionRecovery
}

public struct RefreshEffectSettings: Codable, Equatable {
    public var isEnabled: Bool
    public var isAutoRefreshEnabled: Bool

    public init(
        isEnabled: Bool = true,
        isAutoRefreshEnabled: Bool = true
    ) {
        self.isEnabled = isEnabled
        self.isAutoRefreshEnabled = isAutoRefreshEnabled
    }
}

public enum RefreshEffectPolicy {
    public static func shouldAnimate(
        trigger: RefreshTrigger?,
        settings: RefreshEffectSettings
    ) -> Bool {
        guard settings.isEnabled else {
            return false
        }

        if trigger == .automatic {
            return settings.isAutoRefreshEnabled
        }

        return true
    }
}
