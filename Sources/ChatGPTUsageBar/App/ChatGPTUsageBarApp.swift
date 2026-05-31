import AppKit
import ChatGPTUsageCore
import SwiftUI

@main
struct ChatGPTUsageBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: UsageStore
    @StateObject private var webKitUsageController: WebKitUsageController

    init() {
        let store = UsageStore()
        let webKitUsageController = WebKitUsageController()
        webKitUsageController.attach(store: store)
        _store = StateObject(wrappedValue: store)
        _webKitUsageController = StateObject(wrappedValue: webKitUsageController)
    }

    var body: some Scene {
        MenuBarExtra {
            DashboardView()
                .environmentObject(store)
                .environmentObject(webKitUsageController)
                .frame(width: 440)
                .frame(minHeight: 520)
        } label: {
            Label("ChatGPT Usage", systemImage: "chart.bar.xaxis")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
