import Foundation
import PixelCoreKit

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case japanese = "ja"

    static let storageKey = "pixel-forge.language"
    var id: Self { self }

    static var selected: AppLanguage {
        let stored = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return AppLanguage(rawValue: stored) ?? .system
    }

    func resolvedLanguageCode(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        switch self {
        case .english:
            return "en"
        case .japanese:
            return "ja"
        case .system:
            guard let preferred = preferredLanguages.first else { return "en" }
            let code = Locale(identifier: preferred).language.languageCode?.identifier
            return code == "ja" ? "ja" : "en"
        }
    }

    var locale: Locale {
        Locale(identifier: resolvedLanguageCode())
    }
}

enum AppLocalization {
    static func text(_ key: String, language: AppLanguage = .selected) -> String {
        let code = language.resolvedLanguageCode()
        let rootBundle = Bundle(for: AppBundleToken.self)
        guard
            let path = rootBundle.path(forResource: code, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return rootBundle.localizedString(forKey: key, value: key, table: nil)
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

private final class AppBundleToken {}

enum L10n {
    static var workbenchTitle: String { text("workbench.title") }
    static var homeEyebrow: String { text("home.eyebrow") }
    static var homeSubtitle: String { text("home.subtitle") }
    static var homeEmptyTitle: String { text("home.empty.title") }
    static var homeEmptyDetail: String { text("home.empty.detail") }
    static var chooseImage: String { text("home.choose_image") }
    static var imageSourceEyebrow: String { text("image_source.eyebrow") }
    static var localLibrary: String { text("home.library") }
    static var workbenchEyebrow: String { text("workbench.eyebrow") }
    static var takePhoto: String { text("workbench.take_photo") }
    static var choosePhoto: String { text("workbench.choose_photo") }
    static var chooseFile: String { text("workbench.choose_file") }
    static var settings: String { text("workbench.settings") }
    static var settingsEyebrow: String { text("settings.eyebrow") }
    static var settingsSubtitle: String { text("settings.subtitle") }
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
    static var saveToPhotos: String { text("action.save_to_photos") }
    static var savingToPhotos: String { text("action.saving_to_photos") }
    static var convert: String { text("action.convert") }
    static var adjust: String { text("action.adjust") }
    static var updateImage: String { text("action.update_image") }
    static var saveAsNew: String { text("action.save_as_new") }
    static var delete: String { text("action.delete") }
    static var cancel: String { text("action.cancel") }
    static var close: String { text("action.close") }
    static var returnToSettings: String { text("action.return_to_settings") }
    static var overwrite: String { text("action.overwrite") }
    static var openSettings: String { text("action.open_settings") }
    static var sourceNone: String { text("source.none") }
    static var statusReady: String { text("status.ready") }
    static var statusWaiting: String { text("status.waiting") }
    static var statusRendered: String { text("status.rendered") }
    static var statusRendering: String { text("status.rendering") }
    static var deterministic: String { text("status.deterministic") }
    static var selectFirst: String { text("error.select_first") }
    static var unsupportedImage: String { text("error.unsupported_image") }
    static var conversionOptions: String { text("conversion.options") }
    static var conversionOptionsDetail: String { text("conversion.options.detail") }
    static var longSide: String { text("setting.long_side") }
    static var crop: String { text("setting.crop") }
    static var cropFull: String { text("setting.crop.full") }
    static var cropRectangle: String { text("setting.crop.rectangle") }
    static var palette: String { text("setting.palette") }
    static var paletteSource: String { text("setting.palette.source") }
    static var custom: String { text("setting.custom") }
    static var customPalette: String { text("setting.custom_palette") }
    static var preserveTone: String { text("setting.preserve_tone") }
    static var saturation: String { text("setting.saturation") }
    static var lightness: String { text("setting.lightness") }
    static var outline: String { text("setting.outline") }
    static var none: String { text("setting.none") }
    static var black: String { text("setting.black") }
    static var adaptive: String { text("setting.adaptive") }
    static var threshold: String { text("setting.threshold") }
    static var proOption: String { text("setting.pro_option") }
    static var renderingDetail: String { text("conversion.rendering.detail") }
    static var logicalSize: String { text("result.logical_size") }
    static var outputSize: String { text("result.output_size") }
    static var algorithm: String { text("result.algorithm") }
    static var conversionFailed: String { text("conversion.failed") }
    static var previousImagePreserved: String { text("conversion.previous_preserved") }
    static var stateEditing: String { text("conversion.state.editing") }
    static var stateRendering: String { text("conversion.state.rendering") }
    static var stateResult: String { text("conversion.state.result") }
    static var stateFailure: String { text("conversion.state.failure") }
    static var deleteEyebrow: String { text("delete.eyebrow") }
    static var deleteTitle: String { text("delete.title") }
    static var deleteDetail: String { text("delete.detail") }
    static var proRequired: String { text("error.pro_required") }
    static var invalidPalette: String { text("error.invalid_palette") }
    static var cameraCaptureFailed: String { text("error.camera_capture_failed") }
    static var cameraPermissionTitle: String { text("camera.permission.title") }
    static var cameraPermissionDetail: String { text("camera.permission.detail") }
    static var photoSaveSuccess: String { text("photos.save.success") }
    static var photosAccessDenied: String { text("error.photos_access_denied") }
    static var appearanceTitle: String { text("settings.appearance.title") }
    static var appearanceEyebrow: String { text("settings.appearance.eyebrow") }
    static var appearanceDescription: String { text("settings.appearance.description") }
    static var darkTheme: String { text("settings.theme.dark") }
    static var darkThemeDescription: String { text("settings.theme.dark.description") }
    static var lightTheme: String { text("settings.theme.light") }
    static var lightThemeDescription: String { text("settings.theme.light.description") }
    static var systemTheme: String { text("settings.theme.system") }
    static var systemThemeDescription: String { text("settings.theme.system.description") }
    static var proTitle: String { text("settings.pro.title") }
    static var proDescription: String { text("settings.pro.description") }
    static var purchase: String { text("settings.pro.purchase") }
    static var restorePurchase: String { text("settings.pro.restore") }
    static var supportTitle: String { text("settings.support.title") }
    static var review: String { text("settings.support.review") }
    static var share: String { text("settings.support.share") }
    static var feedback: String { text("settings.support.feedback") }
    static var privacy: String { text("settings.support.privacy") }
    static var terms: String { text("settings.support.terms") }
    static var unavailableUntilConfigured: String { text("settings.support.unavailable") }
    static var aboutTitle: String { text("settings.about.title") }
    static var version: String { text("settings.about.version") }
    static var proStatusUnknown: String { text("settings.pro.status.unknown") }
    static var proStatusLoading: String { text("settings.pro.status.loading") }
    static var proStatusFree: String { text("settings.pro.status.free") }
    static var proStatusPending: String { text("settings.pro.status.pending") }
    static var proStatusPurchased: String { text("settings.pro.status.purchased") }
    static var proStatusRevoked: String { text("settings.pro.status.revoked") }
    static var proStatusFailed: String { text("settings.pro.status.failed") }
    static var typographyTitle: String { text("settings.typography.title") }
    static var typographyDescription: String { text("settings.typography.description") }
    static var typographySample: String { text("settings.typography.sample") }
    static var languageTitle: String { text("settings.language.title") }
    static var languageEyebrow: String { text("settings.language.eyebrow") }
    static var languageDescription: String { text("settings.language.description") }
    static var languageSystem: String { text("settings.language.system") }
    static var languageEnglish: String { text("settings.language.english") }
    static var languageJapanese: String { text("settings.language.japanese") }
    static var developerEyebrow: String { text("settings.developer.eyebrow") }
    static var developerTitle: String { text("settings.developer.title") }
    static var developerDescription: String { text("settings.developer.description") }
    static var developerProToggle: String { text("settings.developer.pro_toggle") }
    static var currentLanguageCode: String { AppLanguage.selected.resolvedLanguageCode() }

    static func pixels(_ value: Int) -> String {
        format("value.pixels", value)
    }

    static func colorCount(_ value: Int) -> String {
        format("value.colors", value)
    }

    static func scale(_ value: Int) -> String {
        format("value.scale", value)
    }

    static func imageCount(_ value: Int) -> String {
        format("home.image_count", value)
    }

    static func photoSaveFailure(_ detail: String) -> String {
        format("error.photo_save_failed", detail)
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
        AppLocalization.text(key)
    }

    private static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: AppLanguage.selected.locale, arguments: arguments)
    }
}
