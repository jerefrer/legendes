import Testing
@testable import VideoTaggingCore

@Suite struct AppearanceModeTests {
    @Test func roundTripsRawValue() {
        for mode in AppearanceMode.allCases {
            #expect(AppearanceMode(rawValue: mode.rawValue) == mode)
        }
    }
    @Test func defaultIsSystem() {
        #expect(AppearanceMode.defaultValue == .system)
    }
    @Test func fallbackForUnknownRaw() {
        #expect(AppearanceMode(storedValue: "bogus") == .system)
        #expect(AppearanceMode(storedValue: "dark") == .dark)
    }
}
