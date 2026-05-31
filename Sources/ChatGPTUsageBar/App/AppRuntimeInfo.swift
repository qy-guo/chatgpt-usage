import ChatGPTUsageCore
import Foundation
import ServiceManagement

enum AppRuntimeInfo {
    static var runMode: AppRunMode {
        isAppBundle ? .appBundle : .development
    }

    static var isAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var versionText: String {
        AppVersionDisplay.text(
            shortVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            buildVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }
}

enum LaunchAtLoginStatus: Equatable {
    case unavailable(String)
    case enabled
    case disabled
    case requiresApproval
    case notFound

    var isEnabled: Bool {
        self == .enabled
    }

    var canToggle: Bool {
        switch self {
        case .unavailable:
            false
        case .enabled, .disabled, .requiresApproval, .notFound:
            true
        }
    }

    var displayText: String {
        switch self {
        case .unavailable:
            "不可用"
        case .enabled:
            "已开启"
        case .disabled:
            "未开启"
        case .requiresApproval:
            "需要系统批准"
        case .notFound:
            "未找到应用"
        }
    }

    var detailText: String {
        switch self {
        case let .unavailable(reason):
            reason
        case .enabled:
            "登录后自动启动"
        case .disabled:
            "可在应用模式下开启"
        case .requiresApproval:
            "请在系统设置中允许登录项"
        case .notFound:
            "请确认应用已安装"
        }
    }
}

enum LaunchAtLoginController {
    static var status: LaunchAtLoginStatus {
        guard AppRuntimeInfo.isAppBundle else {
            return .unavailable("当前通过终端运行，安装为应用后可用")
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .disabled
        }
    }

    static func setEnabled(_ isEnabled: Bool) throws {
        guard AppRuntimeInfo.isAppBundle else {
            throw LaunchAtLoginError.unavailable
        }

        if isEnabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

enum LaunchAtLoginError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "当前通过终端运行，安装为应用后可用"
        }
    }
}
