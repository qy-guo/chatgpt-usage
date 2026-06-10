import ChatGPTUsageCore
import SwiftUI

struct SettingsView: View {
    let autoRefreshSettings: AutoRefreshSettings
    let refreshEffectSettings: RefreshEffectSettings
    let launchAtLoginStatus: LaunchAtLoginStatus
    let launchAtLoginError: String?
    let runModeText: String
    let versionText: String
    let themePreference: AppThemePreference
    let accountCount: Int
    let dataDirectoryPath: String
    let onBack: () -> Void
    let onLaunchAtLoginChange: (Bool) -> Void
    let onAutoRefreshEnabledChange: (Bool) -> Void
    let onAutoRefreshTargetChange: (AutoRefreshTarget) -> Void
    let onAutoRefreshIntervalChange: (AutoRefreshInterval) -> Void
    let onRefreshEffectsEnabledChange: (Bool) -> Void
    let onAutoRefreshEffectsEnabledChange: (Bool) -> Void
    let onThemePreferenceChange: (AppThemePreference) -> Void
    let onOpenDataDirectory: () -> Void
    let onCopyDiagnostics: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader

            GlassSeparator()

            ScrollView {
                VStack(spacing: 10) {
                    SettingsSection(title: "启动", systemImage: "power") {
                        SettingsToggleRow(
                            title: "开机自启",
                            detail: launchAtLoginStatus.detailText,
                            isOn: Binding(
                                get: { launchAtLoginStatus.isEnabled },
                                set: { isEnabled in
                                    onLaunchAtLoginChange(isEnabled)
                                }
                            )
                        )
                        .disabled(!launchAtLoginStatus.canToggle)

                        SettingsInfoRow(
                            title: "当前状态",
                            value: launchAtLoginStatus.displayText,
                            systemImage: "bolt.horizontal.circle"
                        )

                        SettingsInfoRow(
                            title: "运行方式",
                            value: runModeText,
                            systemImage: "terminal"
                        )

                        if let launchAtLoginError {
                            Label(launchAtLoginError, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .lineLimit(2)
                        }
                    }

                    SettingsSection(title: "刷新", systemImage: "arrow.clockwise") {
                        SettingsToggleRow(
                            title: "刷新特效",
                            detail: "刷新时显示边框流光和文字光效",
                            isOn: Binding(
                                get: { refreshEffectSettings.isEnabled },
                                set: { isEnabled in
                                    onRefreshEffectsEnabledChange(isEnabled)
                                }
                            )
                        )

                        AutoRefreshControls(
                            settings: autoRefreshSettings,
                            onEnabledChange: onAutoRefreshEnabledChange,
                            onTargetChange: onAutoRefreshTargetChange,
                            onIntervalChange: onAutoRefreshIntervalChange
                        )

                        SettingsToggleRow(
                            title: "自动刷新特效",
                            detail: "定时自动刷新时也显示特效",
                            isOn: Binding(
                                get: { refreshEffectSettings.isAutoRefreshEnabled },
                                set: { isEnabled in
                                    onAutoRefreshEffectsEnabledChange(isEnabled)
                                }
                            )
                        )
                        .disabled(!refreshEffectSettings.isEnabled || !autoRefreshSettings.isEnabled)
                    }

                    SettingsSection(title: "外观", systemImage: "sparkles") {
                        ThemePreferenceControl(
                            selection: themePreference,
                            onChange: onThemePreferenceChange
                        )
                    }

                    SettingsSection(title: "账号与数据", systemImage: "folder") {
                        SettingsInfoRow(
                            title: "账号档案",
                            value: "\(accountCount) 个",
                            systemImage: "person.2"
                        )

                        SettingsPathRow(
                            title: "数据目录",
                            path: dataDirectoryPath,
                            systemImage: "externaldrive"
                        )

                        HStack(spacing: 8) {
                            SettingsActionButton(
                                title: "打开数据目录",
                                systemImage: "folder"
                            ) {
                                onOpenDataDirectory()
                            }

                            SettingsActionButton(
                                title: "复制脱敏诊断",
                                systemImage: "doc.on.doc"
                            ) {
                                onCopyDiagnostics()
                            }
                        }
                    }

                    SettingsSection(title: "关于", systemImage: "info.circle") {
                        SettingsInfoRow(
                            title: "版本",
                            value: versionText,
                            systemImage: "tag"
                        )
                    }
                }
                .padding(10)
            }
        }
    }

    private var settingsHeader: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(GlassIconButtonStyle(tint: .accentColor))
            .help("返回")

            VStack(alignment: .leading, spacing: 3) {
                Text("设置")
                    .font(.headline.weight(.semibold))
                Text("启动、刷新与数据")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}

private struct SettingsSection<Content: View>: View {
    @Environment(\.dashboardThemePalette) private var palette

    let title: String
    let systemImage: String
    let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                content
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.glassFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(palette.glassOverlay)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(palette.glassStroke, lineWidth: 0.8)
        )
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

private struct ThemePreferenceControl: View {
    let selection: AppThemePreference
    let onChange: (AppThemePreference) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.lefthalf.filled")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text("主题")
                .font(.caption.weight(.semibold))

            Spacer(minLength: 8)

            Picker(
                "主题",
                selection: Binding(
                    get: { selection },
                    set: { themePreference in
                        onChange(themePreference)
                    }
                )
            ) {
                ForEach(AppThemePreference.allCases) { themePreference in
                    Text(themePreference.displayName)
                        .tag(themePreference)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 190)
        }
    }
}

private struct SettingsInfoRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

private struct SettingsPathRow: View {
    let title: String
    let path: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer(minLength: 10)

            Text(path)
                .font(.caption2.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(path)
        }
    }
}

private struct SettingsActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}
