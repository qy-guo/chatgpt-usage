import Foundation

public enum AccountLoginState: String, Codable, Equatable {
    case notLoggedIn
    case sessionDetected
    case confirmed

    public var canRefreshUsage: Bool {
        switch self {
        case .notLoggedIn:
            false
        case .sessionDetected, .confirmed:
            true
        }
    }
}
