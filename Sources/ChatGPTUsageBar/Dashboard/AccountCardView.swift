import ChatGPTUsageCore
import SwiftUI

private struct CurrentAccountBadge: View {
    var body: some View {
        Text("当前")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.cyan)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                Capsule()
                    .fill(Color.cyan.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .strokeBorder(Color.cyan.opacity(0.34), lineWidth: 0.8)
            )
    }
}

private struct LoginStateBadge: View {
    @Environment(\.dashboardThemePalette) private var palette

    let loginState: AccountLoginState

    var body: some View {
        if loginState == .notLoggedIn {
            Text("未登录")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(palette.badgeFill)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(palette.glassStroke, lineWidth: 0.8)
                )
        }
    }
}

struct AccountCardView: View {
    @Environment(\.dashboardThemePalette) private var palette

    let account: AccountProfile
    let isCurrentAccount: Bool
    let isRefreshingUsage: Bool
    let canRefreshUsage: Bool
    let isConfirmingDelete: Bool
    let onTogglePinned: () -> Void
    let onLogin: () -> Void
    let onRefreshUsage: () -> Void
    let onEdit: () -> Void
    let onRequestDelete: () -> Void
    let onCancelDelete: () -> Void
    let onConfirmDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: 10, height: 24)
                    .help("拖动排序")

                SubscriptionBadge(plan: account.subscription)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(account.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)

                        if isCurrentAccount {
                            CurrentAccountBadge()
                        }

                        LoginStateBadge(loginState: account.loginState)
                    }

                    if !account.accountHint.isEmpty {
                        Text(account.accountHint)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    Button(action: onTogglePinned) {
                        Image(systemName: account.isPinned ? "pin.fill" : "pin")
                    }
                    .buttonStyle(GlassIconButtonStyle(tint: .accentColor, isActive: account.isPinned))
                    .help(account.isPinned ? "取消置顶" : "置顶")

                    Button(action: onLogin) {
                        Image(systemName: "person.crop.circle")
                    }
                    .buttonStyle(GlassIconButtonStyle(tint: .primary))
                    .help("打开登录窗口")

                    Button(action: onRefreshUsage) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(GlassIconButtonStyle(tint: .primary))
                    .disabled(isRefreshingUsage || !canRefreshUsage)
                    .help(canRefreshUsage ? "刷新用量" : "登录后可刷新用量")

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(GlassIconButtonStyle(tint: .primary))
                    .help("编辑")

                    Button(role: .destructive, action: onRequestDelete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(GlassIconButtonStyle(tint: .red))
                    .help("删除")
                }
            }

            UsageSummaryView(
                snapshot: account.resolvedUsageSnapshot,
                isRefreshingUsage: isRefreshingUsage
            )

            if isConfirmingDelete {
                Divider()

                HStack(spacing: 8) {
                    Label("删除这个账号档案？", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("取消", action: onCancelDelete)
                        .font(.caption)

                    Button("删除", role: .destructive, action: onConfirmDelete)
                        .font(.caption)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(palette.cardFill)
                .overlay(
                    LinearGradient(
                        colors: palette.cardGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    borderColor,
                    lineWidth: isCurrentAccount ? 1.8 : (account.isPinned ? 1.2 : 1)
                )
        )
        .shadow(
            color: palette.cardShadow,
            radius: 12,
            y: 5
        )
        .shadow(
            color: Color.cyan.opacity(isCurrentAccount ? 0.20 : 0),
            radius: isCurrentAccount ? 9 : 0,
            y: isCurrentAccount ? 2 : 0
        )
    }

    private var borderColor: Color {
        if isCurrentAccount {
            return Color.cyan.opacity(0.78)
        }

        if account.isPinned {
            return Color.accentColor.opacity(0.44)
        }

        return palette.glassStroke
    }
}

private struct UsageSummaryView: View {
    let snapshot: UsageSnapshot
    let isRefreshingUsage: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            statusHeader

            subscriptionExpiryContent

            usageContent

            if let lastError = snapshot.lastError,
               snapshot.fiveHourUsage == nil && snapshot.weeklyUsage == nil {
                Label(lastError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(5)
                    .textSelection(.enabled)
            }
        }
        .padding(.top, 2)
    }

    private var statusHeader: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                if isRefreshingUsage {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 10, height: 10)
                }

                Text("用量")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: usageLabelColumnWidth, alignment: .trailing)

            Spacer()

            if let lastReadAt = snapshot.lastReadAt {
                Text(relative(lastReadAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private var subscriptionExpiryContent: some View {
        if let subscriptionExpiryText = snapshot.subscriptionExpiryText {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("订阅到期")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: usageLabelColumnWidth, alignment: .trailing)

                Text(subscriptionExpiryText)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 8)
            }
        }
    }

    @ViewBuilder
    private var usageContent: some View {
        if snapshot.fiveHourUsage == nil && snapshot.weeklyUsage == nil {
            HStack(spacing: 8) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(isRefreshingUsage ? "正在后台读取 Usage Dashboard" : "登录后用右上角刷新读取用量")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                if let fiveHourUsage = snapshot.fiveHourUsage {
                    UsageLimitProgressView(label: "5h", value: fiveHourUsage)
                }

                if let weeklyUsage = snapshot.weeklyUsage {
                    UsageLimitProgressView(label: "1 week", value: weeklyUsage)
                }
            }
        }
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct UsageLimitProgressView: View {
    let label: String
    let value: String

    private var usage: UsageProgressInfo {
        UsageProgressInfo(value)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: usageLabelColumnWidth, alignment: .trailing)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(usage.remainingText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    if let resetText = usage.resetText {
                        Text("重置 \(resetText)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }

                UsageProgressBar(progress: usage.progress, tint: usage.tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct UsageProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let fillWidth = max(progress > 0 ? 4 : 0, width * progress)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.24))
                    .overlay(
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.20), lineWidth: 0.5)
                    )

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(0.95),
                                tint.opacity(0.78)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                    )
            }
        }
        .frame(height: 5)
    }
}

private struct UsageProgressInfo {
    let rawValue: String
    let percent: Double?
    let resetText: String?

    init(_ rawValue: String) {
        self.rawValue = rawValue
        percent = Self.extractPercent(from: rawValue)
        resetText = Self.extractResetText(from: rawValue)
    }

    var progress: Double {
        guard let percent else {
            return 0
        }

        return min(max(percent / 100, 0), 1)
    }

    var remainingText: String {
        guard let percent else {
            return rawValue
        }

        let rounded = percent.rounded()
        if abs(percent - rounded) < 0.05 {
            return "\(Int(rounded))% 剩余"
        }

        return String(format: "%.1f%% 剩余", percent)
    }

    var tint: Color {
        guard let percent else {
            return .accentColor
        }

        if percent <= 20 {
            return .red
        }

        if percent <= 50 {
            return .orange
        }

        return .green
    }

    var isLow: Bool {
        (percent ?? 100) <= 20
    }

    private static func extractPercent(from value: String) -> Double? {
        guard let range = value.range(of: #"[0-9]+(?:\.[0-9]+)?(?=%)"#, options: .regularExpression) else {
            return nil
        }

        return Double(value[range])
    }

    private static func extractResetText(from value: String) -> String? {
        let parts = value
            .components(separatedBy: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard let resetPart = parts.first(where: {
            $0.localizedCaseInsensitiveContains("重置") || $0.localizedCaseInsensitiveContains("reset")
        }) else {
            return nil
        }

        let cleaned = resetPart
            .replacingOccurrences(
                of: #"(?i)^(重置时间|重置|reset time|resets?|reset)\s*[:：]?\s*"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? resetPart : cleaned
    }
}

private struct SubscriptionBadge: View {
    let plan: SubscriptionPlan

    var body: some View {
        Text(plan.displayName)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                plan.color.opacity(0.96),
                                plan.color.opacity(0.78)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.26), lineWidth: 0.8)
                    )
            )
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}
