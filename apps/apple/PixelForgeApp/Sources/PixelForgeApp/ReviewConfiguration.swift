import Foundation

enum ReviewScreen: String {
    case home
    case imageSourceMenu = "image-source-menu"
    case deleteDialog = "delete-dialog"
    case conversionEditing = "conversion-editing"
    case palettePicker = "palette-picker"
    case recipePresetLibrary = "recipe-preset-library"
    case conversionResult = "conversion-result"
    case settings
    case settingsDeveloper = "settings-developer"
}

struct ReviewConfiguration {
    let screen: ReviewScreen
    let theme: ForgeTheme
    let language: AppLanguage

    static var current: ReviewConfiguration? {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let screenValue = value(after: "--review-screen", in: arguments),
            let screen = ReviewScreen(rawValue: screenValue)
        else {
            return nil
        }
        let theme = value(after: "--review-theme", in: arguments)
            .flatMap(ForgeTheme.init(rawValue:)) ?? .dark
        let language = value(after: "--review-language", in: arguments)
            .flatMap(AppLanguage.init(rawValue:)) ?? .japanese
        return ReviewConfiguration(screen: screen, theme: theme, language: language)
    }

    static var sourceData: Data? {
        guard let url = Bundle.main.url(forResource: "review-gradient", withExtension: "png") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private static func value(after key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard arguments.indices.contains(valueIndex) else { return nil }
        return arguments[valueIndex]
    }
}
