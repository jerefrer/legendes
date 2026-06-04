import Testing
@testable import VideoTaggingCore

@Suite struct SectionPartitionTests {
    @Test func blankPartitionIsSingleEmptySection() {
        let p = SectionPartition(duration: 60_000)
        #expect(p.sections.count == 1)
        #expect(p.sections[0].start == 0)
        #expect(p.sections[0].end == 60_000)
        #expect(p.sections[0].isEmpty)
    }

    @Test func cutSplitsSectionEarlierKeepsTextLaterEmpty() {
        var p = SectionPartition(duration: 60_000)
        p.sections[0].text = "whole"
        p.cut(atMs: 20_000)
        #expect(p.sections.count == 2)
        #expect(p.sections[0].start == 0 && p.sections[0].end == 20_000)
        #expect(p.sections[0].text == "whole")
        #expect(p.sections[1].start == 20_000 && p.sections[1].end == 60_000)
        #expect(p.sections[1].text == "")
    }

    @Test func cutTooCloseToBoundaryIsNoOp() {
        var p = SectionPartition(duration: 60_000)
        p.cut(atMs: 100)   // < minSectionMs from 0
        #expect(p.sections.count == 1)
    }

    @Test func moveEndShiftsSharedBoundary() {
        var p = SectionPartition(duration: 60_000)
        p.cut(atMs: 30_000)
        p.moveBoundary(beforeIndex: 1, toMs: 25_000)
        #expect(p.sections[0].end == 25_000)
        #expect(p.sections[1].start == 25_000)
    }

    @Test func moveBoundaryClampsToNeighbors() {
        var p = SectionPartition(duration: 60_000)
        p.cut(atMs: 30_000)
        p.moveBoundary(beforeIndex: 1, toMs: -5_000)        // below 0+min
        #expect(p.sections[0].end >= 200)
        p.moveBoundary(beforeIndex: 1, toMs: 999_999)       // beyond duration-min
        #expect(p.sections[1].start <= 60_000 - 200)
    }

    @Test func mergeRemovesBoundaryAndJoinsText() {
        var p = SectionPartition(duration: 60_000)
        p.cut(atMs: 30_000)
        p.sections[0].text = "a"
        p.sections[1].text = "b"
        p.merge(boundaryBeforeIndex: 1)
        #expect(p.sections.count == 1)
        #expect(p.sections[0].start == 0 && p.sections[0].end == 60_000)
        #expect(p.sections[0].text == "a\nb")
    }

    @Test func mergeKeepsNonEmptyWhenOneIsEmpty() {
        var p = SectionPartition(duration: 60_000)
        p.cut(atMs: 30_000)
        p.sections[1].text = "only"
        p.merge(boundaryBeforeIndex: 1)
        #expect(p.sections[0].text == "only")
    }

    @Test func normalizeFromEntriesAlignsToContiguous() {
        let entries = [
            SRTEntry(start: 0, end: 54_997, text: "one"),
            SRTEntry(start: 54_998, end: 57_694, text: "two"),   // 1ms gap
            SRTEntry(start: 57_695, end: 124_998, text: "three"),
        ]
        let p = SectionPartition(duration: 124_998, fromEntries: entries)
        #expect(p.sections.count == 3)
        #expect(p.sections[0].start == 0)
        #expect(p.sections[0].end == p.sections[1].start)  // contiguous
        #expect(p.sections[1].end == p.sections[2].start)
        #expect(p.sections[2].end == 124_998)
        #expect(p.sections.map(\.text) == ["one", "two", "three"])
    }

    @Test func sectionIndexForPlayhead() {
        var p = SectionPartition(duration: 60_000)
        p.cut(atMs: 30_000)
        #expect(p.indexContaining(ms: 10_000) == 0)
        #expect(p.indexContaining(ms: 45_000) == 1)
        #expect(p.indexContaining(ms: 30_000) == 1)  // boundary belongs to later
    }

    @Test func indexContainingNegativeMsClampsToZero() {
        let p = SectionPartition(duration: 60_000)
        #expect(p.indexContaining(ms: -1000) == 0)
    }

    @Test func replaceSectionsRestoresState() {
        var p = SectionPartition(duration: 60_000)
        p.cut(atMs: 30_000)
        let snapshot = p.sections
        p.merge(boundaryBeforeIndex: 1)
        #expect(p.sections.count == 1)
        p.replaceSections(snapshot)
        #expect(p.sections.count == 2)
    }
}
