import ChatGPTUsageCore
import SwiftUI

struct AutoRefreshControls: View {
    @Environment(\.dashboardThemePalette) private var palette

    let settings: AutoRefreshSettings
    let onEnabledChange: (Bool) -> Void
    let onTargetChange: (AutoRefreshTarget) -> Void
    let onIntervalChange: (AutoRefreshInterval) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Toggle(
                isOn: Binding(
                    get: { settings.isEnabled },
                    set: { isEnabled in
                        onEnabledChange(isEnabled)
                    }
                )
            ) {
                Text("自动刷新")
                    .font(.caption.weight(.semibold))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("开启自动刷新")

            Spacer(minLength: 6)

            Picker(
                "刷新范围",
                selection: Binding(
                    get: { settings.target },
                    set: { target in
                        onTargetChange(target)
                    }
                )
            ) {
                ForEach(AutoRefreshTarget.allCases) { target in
                    Text(target.displayName)
                        .tag(target)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 92)
            .disabled(!settings.isEnabled)
            .help("自动刷新范围")

            Picker(
                "刷新间隔",
                selection: Binding(
                    get: { settings.interval },
                    set: { interval in
                        onIntervalChange(interval)
                    }
                )
            ) {
                ForEach(AutoRefreshInterval.allCases) { interval in
                    Text(interval.displayName)
                        .tag(interval)
                }
            }
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 80)
            .disabled(!settings.isEnabled)
            .help("自动刷新间隔")
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
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
