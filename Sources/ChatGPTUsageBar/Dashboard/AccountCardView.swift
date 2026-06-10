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

    @State private var observedLastReadAt: Date?
    @State private var successPulseReadAt: Date?

    let account: AccountProfile
    let isCurrentAccount: Bool
    let isRefreshingUsage: Bool
    let isQueuedForRefresh: Bool
    let refreshPhase: UsageRefreshPhase?
    let refreshTrigger: RefreshTrigger?
    let refreshEffectSettings: RefreshEffectSettings
    let isCheckingStoredSession: Bool
    let canRefreshUsage: Bool
    let isConfirmingDelete: Bool
    let onTogglePinned: () -> Void
    let onLogin: () -> Void
    let onCheckStoredSession: () -> Void
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

                    if canCheckStoredSession {
                        Button(action: onCheckStoredSession) {
                            Image(systemName: isCheckingStoredSession ? "hourglass" : "checkmark.shield")
                        }
                        .buttonStyle(GlassIconButtonStyle(tint: .primary))
                        .disabled(isCheckingStoredSession)
                        .help(checkStoredSessionHelp)
                    }

                    Button(action: onRefreshUsage) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(GlassIconButtonStyle(tint: .primary))
                    .disabled(isRefreshingUsage || isQueuedForRefresh || !canRefreshUsage)
                    .help(refreshButtonHelp)

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
                loginState: account.loginState,
                isRefreshingUsage: isRefreshingUsage,
                isQueuedForRefresh: isQueuedForRefresh,
                refreshPhase: refreshPhase,
                isCheckingStoredSession: isCheckingStoredSession,
                isShowingSuccessPulse: isShowingRefreshSuccess,
                usesRefreshTextShimmer: shouldAnimateRefreshEffects
            )

            if isConfirmingDelete {
                Divider()

                HStack(spacing: 8) {
                    Label("删除档案并清除本地登录会话？", systemImage: "exclamationmark.triangle.fill")
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
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(
                        borderColor,
                        lineWidth: cardBorderLineWidth
                    )

                if shouldAnimateRefreshEffects {
                    RefreshingBorderOverlay(
                        cornerRadius: 8,
                        lineWidth: cardBorderLineWidth
                    )
                }
            }
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
        .onAppear {
            observedLastReadAt = latestReadAt
        }
        .onChange(of: account.id) {
            observedLastReadAt = latestReadAt
            successPulseReadAt = nil
        }
        .onChange(of: latestReadAt) { _, newReadAt in
            handleLastReadAtChange(newReadAt)
        }
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

    private var cardBorderLineWidth: CGFloat {
        if isCurrentAccount {
            return 1.8
        }

        if account.isPinned {
            return 1.2
        }

        return 1
    }

    private var refreshButtonHelp: String {
        if isQueuedForRefresh {
            return "刷新已加入队列"
        }

        if canRefreshUsage {
            return "刷新用量"
        }

        return "登录后可刷新用量"
    }

    private var canCheckStoredSession: Bool {
        StoredSessionRecoveryPolicy.canStartRecovery(
            loginState: account.loginState,
            isChecking: false
        ) || isCheckingStoredSession
    }

    private var checkStoredSessionHelp: String {
        if isCheckingStoredSession {
            return "正在检测本地登录状态"
        }

        return "重新检测本地登录状态"
    }

    private var latestReadAt: Date? {
        account.resolvedUsageSnapshot.lastReadAt
    }

    private var hasActiveRefreshFeedback: Bool {
        refreshPhase != nil || isRefreshingUsage || isQueuedForRefresh || isCheckingStoredSession
    }

    private var isShowingRefreshSuccess: Bool {
        guard let latestReadAt,
              let successPulseReadAt else {
            return false
        }

        return latestReadAt == successPulseReadAt
            && !hasActiveRefreshFeedback
            && account.resolvedUsageSnapshot.lastError == nil
    }

    private var shouldAnimateRefreshEffects: Bool {
        guard hasActiveRefreshFeedback else {
            return false
        }

        return RefreshEffectPolicy.shouldAnimate(
            trigger: effectiveRefreshTrigger,
            settings: refreshEffectSettings
        )
    }

    private var effectiveRefreshTrigger: RefreshTrigger? {
        if let refreshTrigger {
            return refreshTrigger
        }

        if isCheckingStoredSession {
            return .sessionRecovery
        }

        return .manual
    }

    private func handleLastReadAtChange(_ newReadAt: Date?) {
        let previousReadAt = observedLastReadAt
        observedLastReadAt = newReadAt

        guard let newReadAt,
              newReadAt != previousReadAt else {
            return
        }

        guard account.resolvedUsageSnapshot.lastError == nil else {
            successPulseReadAt = nil
            return
        }

        successPulseReadAt = newReadAt

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if successPulseReadAt == newReadAt {
                successPulseReadAt = nil
            }
        }
    }
}

private struct UsageSummaryView: View {
    let snapshot: UsageSnapshot
    let loginState: AccountLoginState
    let isRefreshingUsage: Bool
    let isQueuedForRefresh: Bool
    let refreshPhase: UsageRefreshPhase?
    let isCheckingStoredSession: Bool
    let isShowingSuccessPulse: Bool
    let usesRefreshTextShimmer: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            statusHeader

            subscriptionExpiryContent

            usageContent

            if let lastError = snapshot.lastError {
                if !snapshot.hasUsageData {
                    Label(activeFailureMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .lineLimit(5)
                        .textSelection(.enabled)
                        .help(lastError)
                }
            }
        }
        .padding(.top, 2)
    }

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Color.clear
                .frame(width: usageLabelColumnWidth, height: 1)

            RefreshStatusLabel(
                presentation: statusPresentation,
                allowsShimmer: usesRefreshTextShimmer
            )
                .help(statusHelp)
                .layoutPriority(1)

            Spacer(minLength: 8)
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

                Text(emptyUsageText)
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

    private var statusPresentation: UsageRefreshStatusPresentation {
        UsageRefreshStatusPresentation.resolve(
            refreshPhase: refreshPhase,
            isRefreshing: isRefreshingUsage,
            isQueuedForRefresh: isQueuedForRefresh,
            isCheckingStoredSession: isCheckingStoredSession,
            lastReadText: isShowingSuccessPulse ? "刚刚" : snapshot.lastReadAt.map(relative),
            isShowingSuccessPulse: isShowingSuccessPulse,
            hasFailure: snapshot.lastError != nil,
            failureText: snapshot.hasUsageData ? nil : "刷新失败 · 未读取到数据"
        )
    }

    private var emptyUsageText: String {
        if let activeRefreshText {
            return "\(activeRefreshText)，等待用量数据"
        }

        switch loginState {
        case .notLoggedIn:
            return "先点击登录图标完成 ChatGPT 登录"
        case .sessionDetected:
            return "已检测到登录，正在自动读取用量"
        case .confirmed:
            return "登录后用右上角刷新读取用量"
        }
    }

    private var activeRefreshText: String? {
        if let refreshPhase {
            return refreshPhase.displayName
        }

        if isCheckingStoredSession {
            return "确认登录状态"
        }

        if isQueuedForRefresh {
            return "等待刷新队列"
        }

        if isRefreshingUsage {
            return "正在后台读取 Usage Dashboard"
        }

        return nil
    }

    private var statusHelp: String {
        if let refreshPhase {
            return refreshPhase.diagnosticLabel
        }

        if let lastError = snapshot.lastError {
            return lastError
        }

        return statusPresentation.text
    }

    private var activeFailureMessage: String {
        snapshot.lastFailureKind?.displayMessage ?? snapshot.lastError ?? "刷新失败，请稍后重试。"
    }
}

private struct RefreshStatusLabel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let presentation: UsageRefreshStatusPresentation
    let allowsShimmer: Bool

    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        label
            .overlay {
                if presentation.usesShimmer && allowsShimmer && !reduceMotion {
                    shimmerLayer
                        .mask(label)
                }
            }
            .compositingGroup()
            .onAppear(perform: startShimmer)
            .onChange(of: presentation.text) {
                startShimmer()
            }
    }

    private var label: some View {
        Text(presentation.text)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .font(.caption.weight(presentation.tone == .idle ? .medium : .semibold))
            .foregroundStyle(foregroundColor)
    }

    private var foregroundColor: Color {
        switch presentation.tone {
        case .idle:
            return .secondary
        case .refreshing:
            return .primary.opacity(0.76)
        case .success:
            return .green
        case .failure:
            return .orange
        }
    }

    private var shimmerLayer: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let shimmerWidth = min(max(width * 0.42, 34), 82)
            let travelDistance = width + shimmerWidth * 2

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.16), location: 0.32),
                    .init(color: .white.opacity(0.88), location: 0.50),
                    .init(color: .white.opacity(0.16), location: 0.68),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: shimmerWidth)
            .offset(x: shimmerPhase * travelDistance - shimmerWidth)
        }
        .allowsHitTesting(false)
    }

    private func startShimmer() {
        guard presentation.usesShimmer,
              allowsShimmer,
              !reduceMotion else {
            return
        }

        shimmerPhase = 0

        withAnimation(.linear(duration: 1.45).delay(0.18).repeatForever(autoreverses: false)) {
            shimmerPhase = 1
        }
    }
}

private struct RefreshingBorderOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    @State private var phase: Double = 0

    var body: some View {
        let glowLineWidth = max(lineWidth + 1.2, 2.6)
        let strokeStyle = StrokeStyle(
            lineWidth: glowLineWidth,
            lineCap: .round,
            lineJoin: .round
        )
        let borderShape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return ZStack {
            borderShape
                .strokeBorder(Color.cyan.opacity(reduceMotion ? 0.66 : 0.18), style: strokeStyle)

            if !reduceMotion {
                AngularGradient(
                    stops: [
                        .init(color: .clear, location: 0.00),
                        .init(color: .clear, location: 0.48),
                        .init(color: Color.cyan.opacity(0.70), location: 0.55),
                        .init(color: Color.white.opacity(0.92), location: 0.60),
                        .init(color: Color.cyan.opacity(0.70), location: 0.65),
                        .init(color: .clear, location: 0.72),
                        .init(color: .clear, location: 1.00)
                    ],
                    center: .center
                )
                .rotationEffect(.degrees(phase * 360))
                .mask(
                    borderShape
                        .strokeBorder(Color.white, style: strokeStyle)
                )
            }
        }
        .allowsHitTesting(false)
        .onAppear(perform: start)
    }

    private func start() {
        guard !reduceMotion else {
            return
        }

        phase = 0

        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
            phase = 1
        }
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
