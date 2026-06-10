import Foundation

public enum UsageReadFailureKind: String, Codable, Equatable {
    case loginRequired
    case analyticsLoading
    case unexpectedPage
    case parserOutdated
    case timeout
    case webKitEvaluation

    public var displayMessage: String {
        switch self {
        case .loginRequired:
            "登录状态已失效，请重新登录。"
        case .analyticsLoading:
            "Analytics 页面仍在加载使用数据，请稍后重试。"
        case .unexpectedPage:
            "正在切换到 Analytics 页面，请稍后重试。"
        case .parserOutdated:
            "未识别到用量卡片，页面结构可能变化。请复制诊断信息反馈。"
        case .timeout:
            "后台读取 Analytics 超时，请稍后重试。"
        case .webKitEvaluation:
            "后台读取网页内容失败，请重新打开登录窗口确认页面状态。"
        }
    }

    public var compactMessage: String {
        switch self {
        case .loginRequired:
            "登录状态已失效"
        case .analyticsLoading:
            "Analytics 仍在加载"
        case .unexpectedPage:
            "正在切换页面"
        case .parserOutdated:
            "页面结构可能变化"
        case .timeout:
            "后台读取超时"
        case .webKitEvaluation:
            "网页读取失败"
        }
    }
}
