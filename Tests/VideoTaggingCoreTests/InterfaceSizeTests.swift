import Testing
@testable import VideoTaggingCore

@Suite struct InterfaceSizeTests {
    @Test func scaleValues() {
        #expect(InterfaceSize.comfortable.scale == 1.0)
        #expect(InterfaceSize.large.scale == 1.2)
        #expect(InterfaceSize.extraLarge.scale == 1.45)
    }
    @Test func roundTripsRawValue() {
        for size in InterfaceSize.allCases {
            #expect(InterfaceSize(rawValue: size.rawValue) == size)
        }
    }
    @Test func defaultIsComfortable() {
        #expect(InterfaceSize.defaultValue == .comfortable)
    }
    @Test func fallbackForUnknownRaw() {
        #expect(InterfaceSize(storedValue: "bogus") == .comfortable)
        #expect(InterfaceSize(storedValue: "large") == .large)
    }
}
