import ChatGPTUsageCore
import SwiftUI

struct AccountEditorView: View {
    let title: String
    let saveTitle: String
    let onCancel: () -> Void
    let onSave: (AccountProfile) -> Void

    @State private var draft: AccountDraft

    init(
        account: AccountProfile,
        title: String,
        saveTitle: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (AccountProfile) -> Void
    ) {
        self.title = title
        self.saveTitle = saveTitle
        self.onCancel = onCancel
        self.onSave = onSave
        _draft = State(initialValue: AccountDraft(account: account))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline.weight(.semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    accountSection
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("取消") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(saveTitle) {
                    onSave(draft.account)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isValid)
            }
            .padding(16)
        }
        .frame(width: 440)
        .frame(minHeight: 320)
        .background(.regularMaterial)
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("账号")
                .font(.subheadline.weight(.semibold))
            Text("每个账号使用独立的 WebKit 本地会话。添加后可点击登录图标完成登录。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("名称")
                        .foregroundStyle(.secondary)
                    TextField("个人账号", text: $draft.displayName)
                }

                GridRow {
                    Text("备注")
                        .foregroundStyle(.secondary)
                    TextField("邮箱尾号或用途标签", text: $draft.accountHint)
                }

                GridRow {
                    Text("订阅")
                        .foregroundStyle(.secondary)
                    Picker("", selection: $draft.subscription) {
                        ForEach(SubscriptionPlan.allCases) { plan in
                            Text(plan.displayName).tag(plan)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 180, alignment: .leading)
                }

            }
            .font(.callout)
        }
    }
}

private struct AccountDraft {
    let id: UUID
    let createdAt: Date

    var displayName: String
    var accountHint: String
    var subscription: SubscriptionPlan
    var chromeProfileDirectory: String
    var usageSnapshot: UsageSnapshot?
    var isPinned: Bool
    var loginState: AccountLoginState
    var lastSessionCheckAt: Date?

    init(account: AccountProfile) {
        id = account.id
        createdAt = account.createdAt
        displayName = account.displayName
        accountHint = account.accountHint
        subscription = account.subscription
        chromeProfileDirectory = account.chromeProfileDirectory
        usageSnapshot = account.usageSnapshot
        isPinned = account.isPinned
        loginState = account.loginState
        lastSessionCheckAt = account.lastSessionCheckAt
    }

    var isValid: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var account: AccountProfile {
        AccountProfile(
            id: id,
            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            accountHint: accountHint.trimmingCharacters(in: .whitespacesAndNewlines),
            subscription: subscription,
            chromeProfileDirectory: chromeProfileDirectory.trimmingCharacters(in: .whitespacesAndNewlines),
            usageSnapshot: usageSnapshot,
            isPinned: isPinned,
            loginState: loginState,
            lastSessionCheckAt: lastSessionCheckAt,
            createdAt: createdAt,
            updatedAt: Date()
        )
    }
}
