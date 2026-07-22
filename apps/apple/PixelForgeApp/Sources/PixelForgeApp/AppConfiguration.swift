import Foundation

enum AppConfiguration {
    #if PIXEL_FORGE_DEVELOPER
    static let isDeveloperBuild = true
    #else
    static let isDeveloperBuild = false
    #endif

    static let proProductID = environmentValue("PIXEL_FORGE_PRO_PRODUCT_ID")
        ?? "com.kazuvin.pixelforge.pro"

    static let appStoreURL = url(named: "PIXEL_FORGE_APP_STORE_URL")
    static let feedbackURL = url(named: "PIXEL_FORGE_FEEDBACK_URL")
    static let webBaseURL = url(named: "PIXEL_FORGE_WEB_BASE_URL")

    static func supportURL(languageCode: String = AppLanguage.selected.resolvedLanguageCode()) -> URL? {
        localizedWebURL(path: "support", languageCode: languageCode)
    }

    static func privacyURL(languageCode: String = AppLanguage.selected.resolvedLanguageCode()) -> URL? {
        localizedWebURL(path: "privacy", languageCode: languageCode)
    }

    static func termsURL(languageCode: String = AppLanguage.selected.resolvedLanguageCode()) -> URL? {
        localizedWebURL(path: "terms", languageCode: languageCode)
    }

    private static func localizedWebURL(path: String, languageCode: String) -> URL? {
        let locale = languageCode == "en" ? "en" : "ja"
        return webBaseURL?.appendingPathComponent(locale).appendingPathComponent(path)
    }

    private static func url(named name: String) -> URL? {
        environmentValue(name).flatMap(URL.init(string:))
    }

    private static func environmentValue(_ name: String) -> String? {
        let bundled = Bundle.main.object(forInfoDictionaryKey: name) as? String
        let value = (bundled ?? ProcessInfo.processInfo.environment[name])?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
