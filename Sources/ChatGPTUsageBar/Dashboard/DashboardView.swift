import AppKit
import ChatGPTUsageCore
import SwiftUI

struct DashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var webKitUsageController: WebKitUsageController
    @State private var editorContext: AccountEditorContext?
    @State private var pendingDelete: AccountProfile?
    @State private var isShowingSettings = false
    @State private var launchAtLoginStatus = LaunchAtLoginController.status
    @State private var launchAtLoginError: String?
    @State private var draggedAccountID: UUID?
    @State private var dragTranslation: CGSize = .zero
    @State private var accountCardFrames: [UUID: CGRect] = [:]

    var body: some View {
        Group {
            if let editorContext {
                AccountEditorView(
                    account: editorContext.account,
                    title: editorContext.isNew ? "添加账号" : "编辑账号",
                    saveTitle: editorContext.isNew ? "添加" : "保存",
                    onCancel: {
                        self.editorContext = nil
                    },
                    onSave: { savedAccount in
                        if editorContext.isNew {
                            store.add(savedAccount)
                        } else {
                            store.update(savedAccount)
                        }
                        self.editorContext = nil
                    }
                )
            } else if isShowingSettings {
                SettingsView(
                    autoRefreshSettings: store.autoRefreshSettings,
                    launchAtLoginStatus: launchAtLoginStatus,
                    launchAtLoginError: launchAtLoginError,
                    runModeText: AppRuntimeInfo.runMode.displayName,
                    versionText: AppRuntimeInfo.versionText,
                    themePreference: store.themePreference,
                    accountCount: store.accounts.count,
                    dataDirectoryPath: store.dataDirectoryPath,
                    onBack: {
                        isShowingSettings = false
                    },
                    onLaunchAtLoginChange: { isEnabled in
                        setLaunchAtLoginEnabled(isEnabled)
                    },
                    onAutoRefreshEnabledChange: { isEnabled in
                        store.setAutoRefreshEnabled(isEnabled)
                    },
                    onAutoRefreshTargetChange: { target in
                        store.setAutoRefreshTarget(target)
                    },
                    onAutoRefreshIntervalChange: { interval in
                        store.setAutoRefreshInterval(interval)
                    },
                    onThemePreferenceChange: { themePreference in
                        store.setThemePreference(themePreference)
                    },
                    onOpenDataDirectory: {
                        NSWorkspace.shared.open(store.dataDirectoryURL)
                    },
                    onCopyDiagnostics: {
                        copyDiagnostics()
                    }
                )
                .onAppear {
                    refreshLaunchAtLoginStatus()
                }
            } else {
                dashboard
            }
        }
        .environment(\.dashboardThemePalette, dashboardPalette)
        .preferredColorScheme(preferredColorScheme)
        .background(GlassWindowBackground())
    }

    private var dashboard: some View {
        VStack(spacing: 0) {
            header

            GlassSeparator()

            if store.accounts.isEmpty {
                EmptyStateView {
                    pendingDelete = nil
                    editorContext = AccountEditorContext(account: store.makeNewAccount(), isNew: true)
                }
            } else {
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        LazyVStack(spacing: 8) {
                            ForEach(store.accounts) { account in
                                accountCard(for: account)
                                    .background(AccountCardFrameReader(accountID: account.id))
                                    .contentShape(Rectangle())
                                    .opacity(draggedAccountID == account.id ? 0.18 : 1)
                                    .simultaneousGesture(accountDragGesture(for: account.id))
                            }
                        }
                        .padding(10)

                        if let draggedAccount,
                           let frame = accountCardFrames[draggedAccount.id] {
                            accountCard(for: draggedAccount, isOverlay: true)
                                .frame(width: frame.width)
                                .position(x: frame.midX, y: frame.midY + dragTranslation.height)
                                .zIndex(1_000)
                        }
                    }
                }
                .coordinateSpace(name: accountListCoordinateSpace)
                .onPreferenceChange(AccountCardFramePreferenceKey.self) { frames in
                    accountCardFrames = frames
                }
            }

            GlassSeparator()
            footer
        }
    }

    private var draggedAccount: AccountProfile? {
        guard let draggedAccountID else {
            return nil
        }

        return store.accounts.first { $0.id == draggedAccountID }
    }

    private func accountCard(for account: AccountProfile, isOverlay: Bool = false) -> some View {
        AccountCardView(
            account: account,
            isCurrentAccount: store.selectedAccountID == account.id,
            isRefreshingUsage: webKitUsageController.refreshingAccountIDs.contains(account.id),
            canRefreshUsage: account.loginState.canRefreshUsage,
            isConfirmingDelete: !isOverlay && pendingDelete?.id == account.id,
            onTogglePinned: {
                pendingDelete = nil
                withAnimation(.snappy(duration: 0.18)) {
                    store.togglePinned(accountID: account.id)
                }
            },
            onLogin: {
                webKitUsageController.openLogin(account: account)
            },
            onRefreshUsage: {
                webKitUsageController.refreshUsage(account: account)
            },
            onEdit: {
                pendingDelete = nil
                editorContext = AccountEditorContext(account: account, isNew: false)
            },
            onRequestDelete: {
                pendingDelete = account
            },
            onCancelDelete: {
                pendingDelete = nil
            },
            onConfirmDelete: {
                store.deleteAccount(id: account.id)
                pendingDelete = nil
            }
        )
        .onTapGesture {
            guard !isOverlay else {
                return
            }

            pendingDelete = nil
            withAnimation(.snappy(duration: 0.18)) {
                store.selectCurrentAccount(accountID: account.id)
            }
        }
        .allowsHitTesting(!isOverlay)
        .shadow(
            color: .black.opacity(isOverlay ? 0.18 : 0),
            radius: isOverlay ? 12 : 0,
            y: isOverlay ? 5 : 0
        )
    }

    private func accountDragGesture(for accountID: UUID) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named(accountListCoordinateSpace))
            .onChanged { value in
                if draggedAccountID == nil {
                    pendingDelete = nil
                    draggedAccountID = accountID
                }

                guard draggedAccountID == accountID else {
                    return
                }

                dragTranslation = value.translation
            }
            .onEnded { value in
                guard draggedAccountID == accountID else {
                    resetAccountDragState()
                    return
                }

                let targetID = accountDropTargetID(sourceID: accountID, dropY: value.location.y)
                withAnimation(.snappy(duration: 0.18)) {
                    store.moveAccount(sourceID: accountID, beforeTargetID: targetID)
                    resetAccountDragState()
                }
            }
    }

    private func resetAccountDragState() {
        draggedAccountID = nil
        dragTranslation = .zero
    }

    private func accountDropTargetID(sourceID: UUID, dropY: CGFloat) -> UUID? {
        guard let sourceIndex = store.accounts.firstIndex(where: { $0.id == sourceID }) else {
            return nil
        }

        let targets = store.accounts.enumerated().compactMap { index, account in
            guard account.id != sourceID,
                  let frame = accountCardFrames[account.id] else {
                return Optional<(index: Int, id: UUID, frame: CGRect)>.none
            }

            return (index: index, id: account.id, frame: frame)
        }
        .sorted { first, second in
            first.frame.minY < second.frame.minY
        }

        if let hoveredTarget = targets.first(where: { dropY >= $0.frame.minY && dropY <= $0.frame.maxY }) {
            if sourceIndex < hoveredTarget.index {
                return accountID(after: hoveredTarget.id, excluding: sourceID)
            }

            return hoveredTarget.id
        }

        return targets.first(where: { dropY < $0.frame.midY })?.id
    }

    private func accountID(after targetID: UUID, excluding sourceID: UUID) -> UUID? {
        guard let targetIndex = store.accounts.firstIndex(where: { $0.id == targetID }) else {
            return nil
        }

        return store.accounts[(targetIndex + 1)...]
            .first(where: { $0.id != sourceID })?
            .id
    }

    private var canRefreshAllLoggedInAccounts: Bool {
        store.accounts.contains { $0.loginState.canRefreshUsage }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background(GlassIconBackground(isActive: false))

            VStack(alignment: .leading, spacing: 3) {
                Text("ChatGPT Usage")
                    .font(.headline.weight(.semibold))
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                pendingDelete = nil
                webKitUsageController.refreshAllLoggedInAccounts()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(GlassIconButtonStyle(tint: .accentColor))
            .disabled(!canRefreshAllLoggedInAccounts)
            .help("刷新所有已登录账号")

            Button {
                pendingDelete = nil
                refreshLaunchAtLoginStatus()
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(GlassIconButtonStyle(tint: .accentColor))
            .help("设置")

            Button {
                pendingDelete = nil
                editorContext = AccountEditorContext(account: store.makeNewAccount(), isNew: true)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(GlassIconButtonStyle(tint: .accentColor))
            .help("添加账号档案")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if let lastError = store.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(1)
                } else {
                    FooterQuoteView(
                        text: store.footerQuoteText,
                        onRefresh: {
                            store.advanceFooterQuote()
                        }
                    )
                }

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(GlassIconButtonStyle(tint: .red))
                .help("退出")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private var summaryText: String {
        let accountCount = store.accounts.count

        if accountCount == 0 {
            return "还没有账号档案"
        }

        if let selectedAccountID = store.selectedAccountID,
           let selectedAccount = store.accounts.first(where: { $0.id == selectedAccountID }) {
            return "\(accountCount) 个账号，当前：\(selectedAccount.displayName)"
        }

        return "\(accountCount) 个账号，使用独立 WebKit 会话"
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = LaunchAtLoginController.status
    }

    private func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            try LaunchAtLoginController.setEnabled(isEnabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }

        refreshLaunchAtLoginStatus()
    }

    private func copyDiagnostics() {
        let diagnostics = [
            "Version: \(AppRuntimeInfo.versionText)",
            "Run mode: \(AppRuntimeInfo.runMode.displayName)",
            "Launch at login: \(launchAtLoginStatus.displayText)",
            "Accounts: \(store.accounts.count)",
            "Data: \(store.dataDirectoryPath)"
        ].joined(separator: "\n")

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(diagnostics, forType: .string)
    }

    private var systemAppearance: AppThemeAppearance {
        colorScheme == .dark ? .dark : .light
    }

    private var effectiveAppearance: AppThemeAppearance {
        store.themePreference.effectiveAppearance(systemAppearance: systemAppearance)
    }

    private var dashboardPalette: DashboardThemePalette {
        DashboardThemePalette.palette(for: effectiveAppearance)
    }

    private var preferredColorScheme: ColorScheme? {
        switch store.themePreference {
        case .light:
            .light
        case .dark:
            .dark
        case .system:
            nil
        }
    }
}
