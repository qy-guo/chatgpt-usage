import Foundation

public enum AppThemeAppearance: String, Codable, Equatable {
    case light
    case dark
}

public enum AppThemePreference: String, CaseIterable, Codable, Identifiable {
    case light
    case dark
    case system

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .light:
            "明亮"
        case .dark:
            "黑暗"
        case .system:
            "跟随系统"
        }
    }

    public func effectiveAppearance(systemAppearance: AppThemeAppearance) -> AppThemeAppearance {
        switch self {
        case .light:
            .light
        case .dark:
            .dark
        case .system:
            systemAppearance
        }
    }
}

public enum AppRunMode: Equatable {
    case development
    case appBundle

    public var displayName: String {
        switch self {
        case .development:
            "开发模式"
        case .appBundle:
            "应用模式"
        }
    }
}

public enum AppVersionDisplay {
    public static func text(shortVersion: String?, buildVersion: String?) -> String {
        let shortVersion = cleaned(shortVersion)
        guard let shortVersion else {
            return "开发版"
        }

        guard let buildVersion = cleaned(buildVersion) else {
            return shortVersion
        }

        return "\(shortVersion) (\(buildVersion))"
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }
}
