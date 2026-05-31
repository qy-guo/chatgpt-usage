import SwiftUI

struct GlassWindowBackground: View {
    @Environment(\.dashboardThemePalette) private var palette

    var body: some View {
        ZStack {
            Rectangle()
                .fill(palette.windowBase)

            LinearGradient(
                colors: palette.windowGradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    palette.windowHighlight,
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 320
            )
        }
    }
}

struct GlassSeparator: View {
    @Environment(\.dashboardThemePalette) private var palette

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: palette.separator,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}

struct GlassIconBackground: View {
    @Environment(\.dashboardThemePalette) private var palette

    let isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? palette.iconActiveFill : palette.iconFill)
            .overlay(
                Circle()
                    .fill(isActive ? palette.iconActiveOverlay : palette.iconOverlay)
            )
            .overlay(
                Circle()
                    .strokeBorder(isActive ? palette.iconActiveStroke : palette.iconStroke, lineWidth: 1)
            )
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    let tint: Color
    var isActive = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(isActive ? tint : Color.secondary)
            .frame(width: 22, height: 22)
            .background(GlassIconBackground(isActive: isActive || configuration.isPressed))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}
