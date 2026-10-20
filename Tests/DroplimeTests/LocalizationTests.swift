import Testing
@testable import Droplime

struct LocalizationTests {
    @Test func systemLanguageDecidesDefault() {
        #expect(AppLanguage.resolve(preferred: ["de-CH", "en-US"]) == .german)
        #expect(AppLanguage.resolve(preferred: ["de"]) == .german)
        #expect(AppLanguage.resolve(preferred: ["en-GB", "de-DE"]) == .english)
        #expect(AppLanguage.resolve(preferred: ["fr-FR"]) == .english)
        #expect(AppLanguage.resolve(preferred: []) == .english)
    }

    @Test func explicitChoiceWins() {
        #expect(AppLanguage.german.resolved == .german)
        #expect(AppLanguage.english.resolved == .english)
    }

    @Test func bothLanguagesAreTranslated() {
        let de = Strings.german, en = Strings.english
        #expect(de.modeConvert == "Konvertieren" && en.modeConvert == "Convert")
        #expect(de.toolMerge == "Zusammenfügen" && en.toolMerge == "Merge")
        #expect(de.pageSuffix(2) == " – Seite 2" && en.pageSuffix(2) == " – Page 2")
        #expect(en.cannotConvert("a.png", "PDF") == "a.png can’t be converted to PDF.")
    }
}
