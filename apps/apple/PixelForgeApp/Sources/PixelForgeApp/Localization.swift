import Foundation
import PixelCoreKit

enum L10n {
    static var workbenchTitle: String { text("workbench.title") }
    static var workbenchEyebrow: String { text("workbench.eyebrow") }
    static var choosePhoto: String { text("workbench.choose_photo") }
    static var settings: String { text("workbench.settings") }
    static var input: String { text("preview.input") }
    static var output: String { text("preview.output") }
    static var inputEmpty: String { text("preview.input.empty") }
    static var outputEmpty: String { text("preview.output.empty") }
    static var recipeTitle: String { text("recipe.title") }
    static var recipeEyebrow: String { text("recipe.eyebrow") }
    static var recipeSubtitle: String { text("recipe.subtitle") }
    static var width: String { text("setting.width") }
    static var height: String { text("setting.height") }
    static var colors: String { text("setting.colors") }
    static var upscale: String { text("setting.upscale") }
    static var dither: String { text("setting.dither") }
    static var render: String { text("action.render") }
    static var rendering: String { text("action.rendering") }
    static var export: String { text("action.export") }
    static var sourceNone: String { text("source.none") }
    static var statusReady: String { text("status.ready") }
    static var statusWaiting: String { text("status.waiting") }
    static var statusRendered: String { text("status.rendered") }
    static var statusRendering: String { text("status.rendering") }
    static var deterministic: String { text("status.deterministic") }
    static var selectFirst: String { text("error.select_first") }
    static var unsupportedImage: String { text("error.unsupported_image") }
    static var exportPanelMessage: String { text("export.panel_message") }
    static var appearanceTitle: String { text("settings.appearance.title") }
    static var appearanceEyebrow: String { text("settings.appearance.eyebrow") }
    static var appearanceDescription: String { text("settings.appearance.description") }
    static var darkTheme: String { text("settings.theme.dark") }
    static var darkThemeDescription: String { text("settings.theme.dark.description") }
    static var lightTheme: String { text("settings.theme.light") }
    static var lightThemeDescription: String { text("settings.theme.light.description") }
    static var typographyTitle: String { text("settings.typography.title") }
    static var typographyDescription: String { text("settings.typography.description") }
    static var typographySample: String { text("settings.typography.sample") }

    static func pixels(_ value: Int) -> String {
        format("value.pixels", value)
    }

    static func colorCount(_ value: Int) -> String {
        format("value.colors", value)
    }

    static func scale(_ value: Int) -> String {
        format("value.scale", value)
    }

    static func exportFailure(_ detail: String) -> String {
        format("error.export_failed", detail)
    }

    static func ditherName(_ mode: PixelDitherMode) -> String {
        switch mode {
        case .none:
            text("dither.none")
        case .bayer4x4:
            text("dither.bayer")
        case .floydSteinberg:
            text("dither.floyd")
        }
    }

    private static func text(_ key: String) -> String {
        NSLocalizedString(key, bundle: .module, comment: "")
    }

    private static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: .current, arguments: arguments)
    }
}
