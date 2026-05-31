import ChatGPTUsageCore
import SwiftUI

struct AccountEditorContext: Identifiable {
    let account: AccountProfile
    let isNew: Bool

    var id: UUID { account.id }
}

struct AccountCardFrameReader: View {
    let accountID: UUID

    var body: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: AccountCardFramePreferenceKey.self,
                value: [accountID: proxy.frame(in: .named(accountListCoordinateSpace))]
            )
        }
    }
}

struct AccountCardFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

extension SubscriptionPlan {
    var color: Color {
        switch self {
        case .free:
            .gray
        case .plus:
            .green
        case .pro:
            .indigo
        case .team:
            .blue
        case .enterprise:
            .purple
        case .custom:
            .orange
        }
    }
}
