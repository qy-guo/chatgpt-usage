import Foundation

public enum SubscriptionPlan: String, CaseIterable, Codable, Identifiable {
    case free
    case plus
    case pro
    case team
    case enterprise
    case custom

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .free:
            "Free"
        case .plus:
            "Plus"
        case .pro:
            "Pro"
        case .team:
            "Team"
        case .enterprise:
            "Enterprise"
        case .custom:
            "自定义"
        }
    }
}

