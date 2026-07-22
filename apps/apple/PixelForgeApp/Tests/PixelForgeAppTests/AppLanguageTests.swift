import Testing
@testable import PixelForgeApp

@Suite("App language")
struct AppLanguageTests {
    @Test("system language uses Japanese or English and otherwise falls back to English")
    func resolvesSystemLanguage() {
        #expect(AppLanguage.system.resolvedLanguageCode(preferredLanguages: ["ja-JP"]) == "ja")
        #expect(AppLanguage.system.resolvedLanguageCode(preferredLanguages: ["en-US"]) == "en")
        #expect(AppLanguage.system.resolvedLanguageCode(preferredLanguages: ["fr-FR", "ja-JP"]) == "en")
        #expect(AppLanguage.system.resolvedLanguageCode(preferredLanguages: []) == "en")
    }

    @Test("manual language ignores the system preference")
    func resolvesManualLanguage() {
        #expect(AppLanguage.english.resolvedLanguageCode(preferredLanguages: ["ja-JP"]) == "en")
        #expect(AppLanguage.japanese.resolvedLanguageCode(preferredLanguages: ["en-US"]) == "ja")
    }
}
