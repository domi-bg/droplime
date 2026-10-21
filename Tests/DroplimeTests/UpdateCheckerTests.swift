import Testing
@testable import Droplime

struct UpdateCheckerTests {
    @Test func newerVersionIsDetected() {
        #expect(UpdateChecker.isNewer("0.2.0", than: "0.1.0"))
        #expect(UpdateChecker.isNewer("v1.0", than: "0.9.9"))
        #expect(UpdateChecker.isNewer("0.10.0", than: "0.9.0"))
    }

    @Test func sameOrOlderVersionIsNotNewer() {
        #expect(!UpdateChecker.isNewer("0.1.0", than: "0.1.0"))
        #expect(!UpdateChecker.isNewer("0.1.0", than: "0.2.0"))
    }

    @Test func missingTrailingPartsCountAsZero() {
        #expect(!UpdateChecker.isNewer("0.1", than: "0.1.0"))
        #expect(!UpdateChecker.isNewer("0.1.0", than: "0.1"))
    }
}
