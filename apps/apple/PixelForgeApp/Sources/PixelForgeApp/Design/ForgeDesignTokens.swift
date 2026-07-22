import SwiftUI

enum ForgeTheme: String, CaseIterable, Identifiable {
    case system
    case dark
    case light

    static let storageKey = "pixel-forge.appearance-theme"

    var id: Self { self }

    var palette: ForgePalette {
        switch self {
        case .system:
            .dark
        case .dark:
            .dark
        case .light:
            .light
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            nil
        case .dark:
            ColorScheme.dark
        case .light:
            ColorScheme.light
        }
    }

    func resolvedPalette(systemScheme: ColorScheme) -> ForgePalette {
        switch self {
        case .system:
            systemScheme == .dark ? .dark : .light
        case .dark:
            .dark
        case .light:
            .light
        }
    }
}

struct ForgePalette {
    let canvas: Color
    let panel: Color
    let surface: Color
    let surfaceRaised: Color
    let ink: Color
    let muted: Color
    let accent: Color
    let accentInk: Color
    let grid: Color
    let danger: Color
    let success: Color

    static let dark = ForgePalette(
        canvas: forgeColor(0x11141B),
        panel: forgeColor(0x191E29),
        surface: forgeColor(0x242B3B),
        surfaceRaised: forgeColor(0x2D3650),
        ink: forgeColor(0xF5F3EE),
        muted: forgeColor(0x9BA5B7),
        accent: forgeColor(0xEF7A9E),
        accentInk: forgeColor(0x151821),
        grid: forgeColor(0x66728E),
        danger: forgeColor(0xFF8B83),
        success: forgeColor(0x9FD7C0)
    )

    static let light = ForgePalette(
        canvas: forgeColor(0xF2F0E8),
        panel: forgeColor(0xE5E1D5),
        surface: forgeColor(0xFBFAF5),
        surfaceRaised: forgeColor(0xD8DEEA),
        ink: forgeColor(0x1B202A),
        muted: forgeColor(0x657080),
        accent: forgeColor(0xBC3F66),
        accentInk: forgeColor(0xFFF9F4),
        grid: forgeColor(0x8D98AA),
        danger: forgeColor(0xA82E36),
        success: forgeColor(0x28745E)
    )
}

enum ForgeDesign {
    enum Spacing {
        static let hairline: CGFloat = 2
        static let tight: CGFloat = 6
        static let compact: CGFloat = 10
        static let regular: CGFloat = 16
        static let roomy: CGFloat = 24
        static let section: CGFloat = 30
    }

    enum Size {
        static let border: CGFloat = 1
        static let activeBorder: CGFloat = 2
        static let cornerCut: CGFloat = 6
        static let compactCornerCut: CGFloat = 4
        static let previewCornerCut: CGFloat = 8
        static let statusLamp: CGFloat = 7
        static let controlHeight: CGFloat = 44
        static let buttonHeight: CGFloat = 46
        static let toolbarHeight: CGFloat = 82
        static let recipeWidth: CGFloat = 352
    }
}

private struct ForgePaletteKey: EnvironmentKey {
    static let defaultValue = ForgePalette.dark
}

extension EnvironmentValues {
    var forgePalette: ForgePalette {
        get { self[ForgePaletteKey.self] }
        set { self[ForgePaletteKey.self] = newValue }
    }
}

private struct ForgeThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var systemScheme
    let theme: ForgeTheme

    func body(content: Content) -> some View {
        let palette = theme.resolvedPalette(systemScheme: systemScheme)
        content
            .environment(\.forgePalette, palette)
            .preferredColorScheme(theme.colorScheme)
            .tint(palette.accent)
    }
}

extension View {
    func forgeTheme(_ theme: ForgeTheme) -> some View {
        modifier(ForgeThemeModifier(theme: theme))
    }
}

private func forgeColor(_ hex: UInt32) -> Color {
    Color(
        red: Double((hex >> 16) & 0xFF) / 255,
        green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255
    )
}
