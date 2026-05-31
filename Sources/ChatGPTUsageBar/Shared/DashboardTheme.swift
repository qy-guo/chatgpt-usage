import AppKit
import ChatGPTUsageCore
import SwiftUI

let accountListCoordinateSpace = "account-list"
let usageLabelColumnWidth: CGFloat = 68

struct DashboardThemePalette {
    let windowBase: Color
    let windowGradient: [Color]
    let windowHighlight: Color
    let separator: [Color]
    let glassFill: Color
    let glassOverlay: Color
    let glassStroke: Color
    let iconFill: Color
    let iconActiveFill: Color
    let iconOverlay: Color
    let iconActiveOverlay: Color
    let iconStroke: Color
    let iconActiveStroke: Color
    let badgeFill: Color
    let cardFill: Color
    let cardGradient: [Color]
    let cardShadow: Color

    static func palette(for appearance: AppThemeAppearance) -> DashboardThemePalette {
        switch appearance {
        case .light:
            DashboardThemePalette(
                windowBase: Color(red: 0.78, green: 0.82, blue: 0.88),
                windowGradient: [
                    Color.white.opacity(0.36),
                    Color.accentColor.opacity(0.08),
                    Color.black.opacity(0.04)
                ],
                windowHighlight: Color.white.opacity(0.28),
                separator: [
                    Color.white.opacity(0.18),
                    Color.primary.opacity(0.10),
                    Color.white.opacity(0.08)
                ],
                glassFill: Color.white.opacity(0.22),
                glassOverlay: Color.black.opacity(0.03),
                glassStroke: Color.white.opacity(0.24),
                iconFill: Color.white.opacity(0.20),
                iconActiveFill: Color.white.opacity(0.34),
                iconOverlay: Color.black.opacity(0.04),
                iconActiveOverlay: Color.accentColor.opacity(0.16),
                iconStroke: Color.white.opacity(0.24),
                iconActiveStroke: Color.white.opacity(0.42),
                badgeFill: Color.black.opacity(0.06),
                cardFill: Color.white.opacity(0.22),
                cardGradient: [
                    Color.white.opacity(0.34),
                    Color.white.opacity(0.08),
                    Color.black.opacity(0.03)
                ],
                cardShadow: Color.black.opacity(0.10)
            )
        case .dark:
            DashboardThemePalette(
                windowBase: Color(red: 0.10, green: 0.12, blue: 0.16),
                windowGradient: [
                    Color.white.opacity(0.08),
                    Color.accentColor.opacity(0.14),
                    Color.black.opacity(0.30)
                ],
                windowHighlight: Color.white.opacity(0.10),
                separator: [
                    Color.white.opacity(0.10),
                    Color.primary.opacity(0.16),
                    Color.white.opacity(0.04)
                ],
                glassFill: Color.white.opacity(0.10),
                glassOverlay: Color.black.opacity(0.18),
                glassStroke: Color.white.opacity(0.16),
                iconFill: Color.white.opacity(0.12),
                iconActiveFill: Color.white.opacity(0.18),
                iconOverlay: Color.black.opacity(0.20),
                iconActiveOverlay: Color.accentColor.opacity(0.24),
                iconStroke: Color.white.opacity(0.18),
                iconActiveStroke: Color.white.opacity(0.30),
                badgeFill: Color.white.opacity(0.08),
                cardFill: Color.white.opacity(0.10),
                cardGradient: [
                    Color.white.opacity(0.16),
                    Color.white.opacity(0.05),
                    Color.black.opacity(0.20)
                ],
                cardShadow: Color.black.opacity(0.32)
            )
        }
    }
}

private struct DashboardThemePaletteKey: EnvironmentKey {
    static let defaultValue = DashboardThemePalette.palette(for: .light)
}

extension EnvironmentValues {
    var dashboardThemePalette: DashboardThemePalette {
        get { self[DashboardThemePaletteKey.self] }
        set { self[DashboardThemePaletteKey.self] = newValue }
    }
}
