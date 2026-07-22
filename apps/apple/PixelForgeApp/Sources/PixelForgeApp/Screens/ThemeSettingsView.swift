import SwiftUI

struct ThemeSettingsView: View {
    @AppStorage(ForgeTheme.storageKey) private var themeRawValue = ForgeTheme.dark.rawValue

    var body: some View {
        ForgeCanvas {
            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.roomy) {
                ForgeSectionHeader(
                    eyebrow: L10n.appearanceEyebrow,
                    title: L10n.appearanceTitle,
                    detail: L10n.appearanceDescription
                )

                HStack(spacing: ForgeDesign.Spacing.regular) {
                    ForgeThemeCard(
                        theme: .dark,
                        title: L10n.darkTheme,
                        detail: L10n.darkThemeDescription,
                        isSelected: selectedTheme == .dark
                    ) {
                        themeRawValue = ForgeTheme.dark.rawValue
                    }
                    ForgeThemeCard(
                        theme: .light,
                        title: L10n.lightTheme,
                        detail: L10n.lightThemeDescription,
                        isSelected: selectedTheme == .light
                    ) {
                        themeRawValue = ForgeTheme.light.rawValue
                    }
                }

                ForgeSectionHeader(
                    eyebrow: "DOTGOTHIC16 / OFL",
                    title: L10n.typographyTitle
                )
                ForgeTypographySample(
                    sample: L10n.typographySample,
                    detail: L10n.typographyDescription
                )
            }
            .padding(ForgeDesign.Spacing.roomy)
        }
        .frame(width: 620, height: 420)
    }

    private var selectedTheme: ForgeTheme {
        ForgeTheme(rawValue: themeRawValue) ?? .dark
    }
}
