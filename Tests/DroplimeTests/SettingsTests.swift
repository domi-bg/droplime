import Foundation
import Testing
@testable import Droplime

@MainActor
struct SettingsTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "DroplimeTests-\(UUID())")!
    }

    @Test func defaults() {
        let settings = Settings(defaults: makeDefaults())
        #expect(settings.playSound)
        #expect(settings.lossyQuality == 0.9)
    }

    @Test func valuesRoundTrip() {
        let defaults = makeDefaults()
        let settings = Settings(defaults: defaults)
        settings.playSound = false
        settings.lossyQuality = 0.7
        let reloaded = Settings(defaults: defaults)
        #expect(!reloaded.playSound)
        #expect(reloaded.lossyQuality == 0.7)
    }

    @Test func qualityIsClamped() {
        let defaults = makeDefaults()
        let settings = Settings(defaults: defaults)
        settings.lossyQuality = 0.1
        #expect(settings.lossyQuality == 0.5)
        settings.lossyQuality = 3
        #expect(settings.lossyQuality == 1.0)
        defaults.set(0.0, forKey: "lossyQuality")
        #expect(Settings(defaults: defaults).lossyQuality == 0.5)
    }
}
