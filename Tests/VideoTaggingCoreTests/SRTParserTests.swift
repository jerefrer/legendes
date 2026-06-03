import Foundation
import Testing
@testable import VideoTaggingCore

@Suite struct SRTParserTests {
    @Test func parsesBasicBlocks() {
        let srt = """
        1
        00:00:00,000 --> 00:00:54,997
        Wide shot of the venue

        2
        00:00:54,998 --> 00:00:57,694
        Close-up
        """
        let entries = SRTParser.parse(srt)
        #expect(entries.count == 2)
        #expect(entries[0].start == 0)
        #expect(entries[0].end == 54_997)
        #expect(entries[0].text == "Wide shot of the venue")
        #expect(entries[1].text == "Close-up")
    }

    @Test func preservesMultiLineText() {
        let srt = """
        1
        00:00:00,000 --> 00:00:10,000
        line one
        line two
        """
        let entries = SRTParser.parse(srt)
        #expect(entries[0].text == "line one\nline two")
    }

    @Test func skipsMalformedBlocksButKeepsValidOnes() {
        let srt = """
        1
        garbage timecode
        ignored

        2
        00:00:05,000 --> 00:00:09,000
        kept
        """
        let entries = SRTParser.parse(srt)
        #expect(entries.count == 1)
        #expect(entries[0].text == "kept")
    }

    @Test func parsesRealSampleFile() throws {
        let url = try #require(Bundle.module.url(forResource: "sample", withExtension: "srt"))
        let srt = try String(contentsOf: url, encoding: .utf8)
        let entries = SRTParser.parse(srt)
        #expect(entries.count == 53)
        #expect(entries.first?.start == 0)
        #expect(entries.last?.end == 3_746_333)
    }
}
