import Testing
@testable import VideoTaggingCore

@Suite struct SRTTimeTests {
    @Test func parsesSrtTimecode() throws {
        #expect(try SRTTime.parse("00:00:54,997").milliseconds == 54_997)
        #expect(try SRTTime.parse("01:02:26,333").milliseconds == 3_746_333)
    }

    @Test func rejectsMalformedTimecode() {
        #expect(throws: (any Error).self) { try SRTTime.parse("nonsense") }
    }

    @Test func formatsSrtTimecode() {
        #expect(SRTTime(milliseconds: 54_997).srtString == "00:00:54,997")
        #expect(SRTTime(milliseconds: 3_746_333).srtString == "01:02:26,333")
    }

    @Test func clampsNegativeMilliseconds() {
        #expect(SRTTime(milliseconds: -5000).milliseconds == 0)
    }

    @Test func displayShortAndLong() {
        #expect(SRTTime(milliseconds: 54_997).displayString == "0:54")
        #expect(SRTTime(milliseconds: 747_000).displayString == "12:27")
        #expect(SRTTime(milliseconds: 3_746_333).displayString == "1:02:26")
    }

    @Test func displayWithMillis() {
        #expect(SRTTime(milliseconds: 54_997).displayStringWithMillis == "0:54.997")
        #expect(SRTTime(milliseconds: 747_350).displayStringWithMillis == "12:27.350")
        #expect(SRTTime(milliseconds: 3_746_333).displayStringWithMillis == "1:02:26.333")
    }
}
