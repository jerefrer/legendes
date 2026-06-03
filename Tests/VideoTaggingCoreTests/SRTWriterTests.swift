import Testing
@testable import VideoTaggingCore

@Suite struct SRTWriterTests {
    @Test func writesAndRenumbersExcludingEmpty() {
        let sections = [
            Section(start: 0, end: 5_000, text: "first"),
            Section(start: 5_000, end: 9_000, text: ""),          // gap -> excluded
            Section(start: 9_000, end: 12_000, text: "third"),
        ]
        let out = SRTWriter.write(sections)
        let expected = """
        1
        00:00:00,000 --> 00:00:05,000
        first

        2
        00:00:09,000 --> 00:00:12,000
        third

        """
        #expect(out == expected)
    }

    @Test func writesEmptySectionsToEmptyString() {
        #expect(SRTWriter.write([]) == "")
        let allEmpty = [
            Section(start: 0, end: 5_000, text: ""),
            Section(start: 5_000, end: 10_000, text: ""),
        ]
        #expect(SRTWriter.write(allEmpty) == "")
    }

    @Test func preservesMultiLineDescriptions() {
        let sections = [Section(start: 0, end: 1_000, text: "a\nb")]
        let out = SRTWriter.write(sections)
        #expect(out.contains("a\nb"))
    }

    @Test func roundTripsThroughParser() {
        let sections = [
            Section(start: 0, end: 5_000, text: "one"),
            Section(start: 5_000, end: 12_000, text: "two"),
        ]
        let entries = SRTParser.parse(SRTWriter.write(sections))
        #expect(entries.count == 2)
        #expect(entries[0].start == 0 && entries[0].end == 5_000 && entries[0].text == "one")
        #expect(entries[1].start == 5_000 && entries[1].end == 12_000 && entries[1].text == "two")
    }
}
