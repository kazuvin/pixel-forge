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
    static var done: String { text("action.done") }
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
    static var conversionStyleEyebrow: String { text("conversion_style.eyebrow") }
    static var conversionStyleTitle: String { text("conversion_style.title") }
    static var conversionStyleDetail: String { text("conversion_style.detail") }
    static var conversionStylePickerTitle: String { text("conversion_style.picker.title") }
    static var conversionStylePickerDetail: String { text("conversion_style.picker.detail") }
    static var conversionStyleBuiltInEyebrow: String { text("conversion_style.built_in.eyebrow") }
    static var conversionStyleBuiltInTitle: String { text("conversion_style.built_in.title") }
    static var conversionStyleBuiltInDetail: String { text("conversion_style.built_in.detail") }
    static var conversionStyleMyPresetsTitle: String { text("conversion_style.my_presets.title") }
    static var conversionStyleMyPresetsDetail: String { text("conversion_style.my_presets.detail") }
    static var conversionStyleSavedDetail: String { text("conversion_style.saved.detail") }
    static var conversionStyleCustom: String { text("conversion_style.custom") }
    static var conversionStyleStandard: String { text("conversion_style.standard") }
    static var conversionStyleStandardDetail: String { text("conversion_style.standard.detail") }
    static var conversionStyleChunky: String { text("conversion_style.chunky") }
    static var conversionStyleChunkyDetail: String { text("conversion_style.chunky.detail") }
    static var conversionStyleFine: String { text("conversion_style.fine") }
    static var conversionStyleFineDetail: String { text("conversion_style.fine.detail") }
    static var conversionStyleGameSprite: String { text("conversion_style.game_sprite") }
    static var conversionStyleGameSpriteDetail: String { text("conversion_style.game_sprite.detail") }
    static var conversionStyleSoftPortrait: String { text("conversion_style.soft_portrait") }
    static var conversionStyleSoftPortraitDetail: String { text("conversion_style.soft_portrait.detail") }
    static var conversionStyleMonoInk: String { text("conversion_style.mono_ink") }
    static var conversionStyleMonoInkDetail: String { text("conversion_style.mono_ink.detail") }
    static var advancedSettingsEyebrow: String { text("advanced_settings.eyebrow") }
    static var advancedSettingsTitle: String { text("advanced_settings.title") }
    static var advancedSettingsDetail: String { text("advanced_settings.detail") }
    static var advancedSettingsPanelDetail: String { text("advanced_settings.panel_detail") }
    static var longSide: String { text("setting.long_side") }
    static var palette: String { text("setting.palette") }
    static var paletteSource: String { text("setting.palette.source") }
    static var paletteSourceDetail: String { text("setting.palette.source.detail") }
    static var paletteSourceCardDetail: String { text("setting.palette.source.card_detail") }
    static var paletteCustomCardDetail: String { text("setting.palette.custom.card_detail") }
    static var paletteEyebrow: String { text("palette.picker.eyebrow") }
    static var palettePickerTitle: String { text("palette.picker.title") }
    static var palettePickerDetail: String { text("palette.picker.detail") }
    static var paletteCollectionEyebrow: String { text("palette.collection.eyebrow") }
    static var paletteCollectionTitle: String { text("palette.collection.title") }
    static var paletteCollectionDetail: String { text("palette.collection.detail") }
    static var paletteApplicationEyebrow: String { text("palette.application.eyebrow") }
    static var paletteApplicationTitle: String { text("palette.application.title") }
    static var paletteApplicationDetail: String { text("palette.application.detail") }
    static var paletteExact: String { text("palette.application.exact") }
    static var palettePresetGameBoy: String { text("palette.preset.game_boy") }
    static var palettePresetPico8: String { text("palette.preset.pico_8") }
    static var palettePresetMonoInk: String { text("palette.preset.mono_ink") }
    static var palettePresetOcean8: String { text("palette.preset.ocean_8") }
    static var palettePresetSunset8: String { text("palette.preset.sunset_8") }
    static var palettePresetForest8: String { text("palette.preset.forest_8") }
    static var palettePresetCandy8: String { text("palette.preset.candy_8") }
    static var palettePresetSepia6: String { text("palette.preset.sepia_6") }
    static var recipePresetEyebrow: String { text("recipe_preset.eyebrow") }
    static var recipePresetTitle: String { text("recipe_preset.title") }
    static var recipePresetDetail: String { text("recipe_preset.detail") }
    static var recipePresetLibraryTitle: String { text("recipe_preset.library.title") }
    static var recipePresetLibraryDetail: String { text("recipe_preset.library.detail") }
    static var recipePresetName: String { text("recipe_preset.name") }
    static var recipePresetSave: String { text("recipe_preset.save") }
    static var recipePresetApply: String { text("recipe_preset.apply") }
    static var recipePresetEmptyTitle: String { text("recipe_preset.empty.title") }
    static var recipePresetEmptyDetail: String { text("recipe_preset.empty.detail") }
    static var presetNameRequired: String { text("error.recipe_preset.name_required") }
    static var presetReviewSoftPortrait: String { text("recipe_preset.review.soft_portrait") }
    static var presetReviewGameSprite: String { text("recipe_preset.review.game_sprite") }
    static var presetDeleteEyebrow: String { text("recipe_preset.delete.eyebrow") }
    static var presetDeleteTitle: String { text("recipe_preset.delete.title") }
    static var presetDeleteDetail: String { text("recipe_preset.delete.detail") }
    static var custom: String { text("setting.custom") }
    static var customPalette: String { text("setting.custom_palette") }
    static var customPaletteColorsTitle: String { text("custom_palette.colors.title") }
    static var customPaletteColorsDetail: String { text("custom_palette.colors.detail") }
    static var customPaletteAddColor: String { text("custom_palette.add_color") }
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
    static var invalidPhotoImage: String { text("error.photo_image_invalid") }
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

    static func paletteColorCount(_ value: Int) -> String {
        format("palette.color_count", value)
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

    static func recipePresetCount(_ value: Int) -> String {
        format("recipe_preset.count", value)
    }

    static func presetSummary(_ longSide: Int, _ upscale: Int, _ palette: String) -> String {
        format("recipe_preset.summary", longSide, upscale, palette)
    }

    static func presetVersion(_ version: String) -> String {
        format("recipe_preset.version", version)
    }

    static func presetSaved(_ name: String) -> String {
        format("recipe_preset.saved", name)
    }

    static func presetDeleted(_ name: String) -> String {
        format("recipe_preset.deleted", name)
    }

    static func presetOperationFailed(_ detail: String) -> String {
        format("error.recipe_preset.operation_failed", detail)
    }

    static func recipeVersionFallback(_ stored: String, _ current: String) -> String {
        format("recipe.version_fallback", stored, current)
    }

    static func presetVersionFallback(_ name: String, _ stored: String, _ current: String) -> String {
        format("recipe_preset.version_fallback", name, stored, current)
    }

    static func customPaletteDeleteColor(_ index: Int) -> String {
        format("custom_palette.delete_color", index)
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
