import Foundation

public enum UsageRefreshPhase: String, Codable, Equatable {
    case queued
    case openingAnalytics
    case checkingLogin
    case readingAnalytics
    case waitingForAnalytics
    case readingSubscription
    case savingResult

    public var displayName: String {
        switch self {
        case .queued:
            "等待刷新队列"
        case .openingAnalytics:
            "打开 Analytics 页面"
        case .checkingLogin:
            "确认登录状态"
        case .readingAnalytics:
            "读取 Analytics 用量"
        case .waitingForAnalytics:
            "等待 Analytics 加载"
        case .readingSubscription:
            "读取订阅信息"
        case .savingResult:
            "保存刷新结果"
        }
    }

    public var diagnosticLabel: String {
        "\(rawValue): \(displayName)"
    }
}
