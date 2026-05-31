import SwiftUI

struct FooterQuoteView: View {
    let text: String
    let onRefresh: () -> Void

    var body: some View {
        Label {
            Text(text)
                .lineLimit(1)
                .truncationMode(.tail)
        } icon: {
            Image(systemName: "quote.bubble.fill")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .contentShape(Rectangle())
        .onTapGesture(perform: onRefresh)
        .help("换一句")
        .layoutPriority(1)
        .accessibilityAddTraits(.isButton)
    }
}

struct EmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.crop.square.stack")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.secondary)

            VStack(spacing: 5) {
                Text("添加第一个账号档案")
                    .font(.headline)
                Text("每个账号使用独立 WebKit 会话登录。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                onAdd()
            } label: {
                Label("添加账号", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}
