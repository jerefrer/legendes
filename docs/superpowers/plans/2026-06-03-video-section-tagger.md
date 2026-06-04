# Video Section Tagger Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native macOS app (SwiftUI) for dividing a video into contiguous, described sections, stored as `.srt`, built for a non-technical 80-year-old user — large UI, few controls, auto-save.

**Architecture:** A Swift Package with two products: `VideoTaggingCore` (pure logic — SRT parse/write, the contiguous-partition model and its operations, file pairing, backups; fully unit-tested with `swift test`) and `VideoTagging` (a SwiftUI executable that owns the `AVPlayer` and the views, depending on Core). MVVM: a `@MainActor @Observable` `EditorViewModel` holds the project + playback state and drives auto-save.

**Tech Stack:** Swift 6.2, SwiftUI + AVKit, Swift Package Manager, Swift Testing (`import Testing`). Deployment target macOS 14.

---

## File Structure

```
Package.swift
Sources/
  VideoTaggingCore/
    Time/SRTTime.swift              // ms <-> "HH:MM:SS,mmm", display formatting
    Models/Section.swift            // Section { id, start, end, text }
    Models/SRTEntry.swift           // raw parsed entry
    SRT/SRTParser.swift             // tolerant parse -> [SRTEntry]
    SRT/SRTWriter.swift             // [Section] -> srt string (excludes empty, renumbers)
    Partition/SectionPartition.swift// contiguous partition + cut/merge/move/normalize
    Files/FileKind.swift            // classify url by extension
    Files/FilePairing.swift         // resolve dropped urls -> (video, srt?) or error
    Files/BackupService.swift       // timestamped backup of an existing srt
  VideoTagging/
    VideoTaggingApp.swift           // @main, window, activation policy
    Theme/Theme.swift               // colors, fonts (large), spacing
    Constants/Strings.swift         // all UI copy (English)
    State/EditorViewModel.swift     // @Observable: project, AVPlayer, current index, autosave
    State/AppRouter.swift           // .dropZone | .editor(EditorViewModel)
    Features/DropZone/DropZoneView.swift
    Features/Editor/EditorView.swift
    Features/Editor/SectionCardView.swift
    Features/Editor/TransportBar.swift
    Features/Editor/TimelineView.swift
    Features/SectionList/SectionListPanel.swift
    Components/BigButton.swift
    Components/TimeLabel.swift
    Services/AutosaveService.swift  // debounced write of srt
Tests/
  VideoTaggingCoreTests/
    SRTTimeTests.swift
    SRTParserTests.swift
    SRTWriterTests.swift
    SectionPartitionTests.swift
    FilePairingTests.swift
    BackupServiceTests.swift
    Resources/sample.srt            // copy of the real sample for round-trip test
```

---

# PHASE 1 — Core logic (no UI), full TDD

### Task 1: Package skeleton

**Files:**
- Create: `Package.swift`
- Create: `Sources/VideoTaggingCore/Time/SRTTime.swift` (placeholder type so the target compiles)

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VideoTagging",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VideoTaggingCore", targets: ["VideoTaggingCore"]),
        .executable(name: "VideoTagging", targets: ["VideoTagging"]),
    ],
    targets: [
        .target(name: "VideoTaggingCore"),
        .executableTarget(
            name: "VideoTagging",
            dependencies: ["VideoTaggingCore"]
        ),
        .testTarget(
            name: "VideoTaggingCoreTests",
            dependencies: ["VideoTaggingCore"],
            resources: [.copy("Resources/sample.srt")]
        ),
    ]
)
```

- [ ] **Step 2: Create a minimal source file so the Core target builds**

`Sources/VideoTaggingCore/Time/SRTTime.swift`:
```swift
import Foundation

public enum VideoTaggingCore {}
```

- [ ] **Step 3: Create the executable entry so the package resolves**

`Sources/VideoTagging/VideoTaggingApp.swift`:
```swift
// Temporary placeholder; replaced in Phase 2.
@main
struct Placeholder {
    static func main() {}
}
```

- [ ] **Step 4: Create the sample resource**

Copy the real sample into the test bundle:
```bash
cp "sample.srt" Tests/VideoTaggingCoreTests/Resources/sample.srt
```
(Create the directory first: `mkdir -p Tests/VideoTaggingCoreTests/Resources`.)

- [ ] **Step 5: Verify it builds**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "chore: scaffold swift package (core + app + tests)"
```

---

### Task 2: SRTTime — ms <-> timecode and display

**Files:**
- Modify: `Sources/VideoTaggingCore/Time/SRTTime.swift`
- Test: `Tests/VideoTaggingCoreTests/SRTTimeTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/VideoTaggingCoreTests/SRTTimeTests.swift`:
```swift
import Testing
@testable import VideoTaggingCore

@Suite struct SRTTimeTests {
    @Test func parsesSrtTimecode() throws {
        #expect(try SRTTime.parse("00:00:54,997").milliseconds == 54_997)
        #expect(try SRTTime.parse("01:02:26,333").milliseconds == 60_000)
    }

    @Test func rejectsMalformedTimecode() {
        #expect(throws: (any Error).self) { try SRTTime.parse("nonsense") }
    }

    @Test func formatsSrtTimecode() {
        #expect(SRTTime(milliseconds: 54_997).srtString == "00:00:54,997")
        #expect(SRTTime(milliseconds: 60_000).srtString == "01:02:26,333")
    }

    @Test func displayShortAndLong() {
        #expect(SRTTime(milliseconds: 54_997).displayString == "0:54")
        #expect(SRTTime(milliseconds: 747_000).displayString == "12:27")
        #expect(SRTTime(milliseconds: 60_000).displayString == "1:02:26")
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter SRTTimeTests`
Expected: FAIL (SRTTime members missing).

- [ ] **Step 3: Implement**

`Sources/VideoTaggingCore/Time/SRTTime.swift`:
```swift
import Foundation

public enum VideoTaggingCore {}

public struct SRTTime: Equatable, Comparable, Sendable {
    public var milliseconds: Int
    public init(milliseconds: Int) { self.milliseconds = max(0, milliseconds) }

    public static func < (a: SRTTime, b: SRTTime) -> Bool {
        a.milliseconds < b.milliseconds
    }

    public enum ParseError: Error { case malformed(String) }

    /// Parses "HH:MM:SS,mmm" (the SRT timecode form).
    public static func parse(_ s: String) throws -> SRTTime {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: ",")
        guard parts.count == 2,
              let ms = Int(parts[1]) else { throw ParseError.malformed(s) }
        let hms = parts[0].split(separator: ":")
        guard hms.count == 3,
              let h = Int(hms[0]), let m = Int(hms[1]), let sec = Int(hms[2])
        else { throw ParseError.malformed(s) }
        return SRTTime(milliseconds: ((h * 3600 + m * 60 + sec) * 1000) + ms)
    }

    public var srtString: String {
        let ms = milliseconds % 1000
        let totalSeconds = milliseconds / 1000
        let s = totalSeconds % 60
        let m = (totalSeconds / 60) % 60
        let h = totalSeconds / 3600
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }

    /// Compact display: "m:ss" under an hour, "h:mm:ss" past it.
    public var displayString: String {
        let totalSeconds = milliseconds / 1000
        let s = totalSeconds % 60
        let m = (totalSeconds / 60) % 60
        let h = totalSeconds / 3600
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter SRTTimeTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoTaggingCore/Time Tests/VideoTaggingCoreTests/SRTTimeTests.swift
git commit -m "feat(core): SRTTime parse/format/display"
```

---

### Task 3: Section and SRTEntry models

**Files:**
- Create: `Sources/VideoTaggingCore/Models/Section.swift`
- Create: `Sources/VideoTaggingCore/Models/SRTEntry.swift`
- Test: covered indirectly later; add a tiny test here.
- Test: `Tests/VideoTaggingCoreTests/SectionPartitionTests.swift` (start the file)

- [ ] **Step 1: Implement models (no test needed beyond compile; they are data)**

`Sources/VideoTaggingCore/Models/Section.swift`:
```swift
import Foundation

public struct Section: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var start: Int   // milliseconds
    public var end: Int     // milliseconds
    public var text: String

    public init(id: UUID = UUID(), start: Int, end: Int, text: String = "") {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    public var durationMs: Int { end - start }
}
```

`Sources/VideoTaggingCore/Models/SRTEntry.swift`:
```swift
public struct SRTEntry: Equatable, Sendable {
    public var start: Int   // milliseconds
    public var end: Int     // milliseconds
    public var text: String
    public init(start: Int, end: Int, text: String) {
        self.start = start
        self.end = end
        self.text = text
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 3: Commit**

```bash
git add Sources/VideoTaggingCore/Models
git commit -m "feat(core): Section and SRTEntry models"
```

---

### Task 4: SRTParser — tolerant parse to [SRTEntry]

**Files:**
- Create: `Sources/VideoTaggingCore/SRT/SRTParser.swift`
- Test: `Tests/VideoTaggingCoreTests/SRTParserTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
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

    @Test func parsesSampleFile() throws {
        let url = try #require(Bundle.module.url(forResource: "sample", withExtension: "srt"))
        let srt = try String(contentsOf: url, encoding: .utf8)
        let entries = SRTParser.parse(srt)
        #expect(entries.count == 6)
        #expect(entries.first?.start == 0)
        #expect(entries.last?.end == 60_000)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter SRTParserTests`
Expected: FAIL (SRTParser missing).

- [ ] **Step 3: Implement**

`Sources/VideoTaggingCore/SRT/SRTParser.swift`:
```swift
import Foundation

public enum SRTParser {
    /// Tolerant parse. Splits on blank lines, ignores the index line,
    /// requires a valid "start --> end" line; skips blocks that lack one.
    public static func parse(_ content: String) -> [SRTEntry] {
        let normalized = content.replacingOccurrences(of: "\r\n", with: "\n")
                                .replacingOccurrences(of: "\r", with: "\n")
        let blocks = normalized.components(separatedBy: "\n\n")
        var entries: [SRTEntry] = []
        for block in blocks {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: false)
                             .map(String.init)
            guard let arrowIndex = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let parts = lines[arrowIndex].components(separatedBy: "-->")
            guard parts.count == 2,
                  let start = try? SRTTime.parse(parts[0]),
                  let end = try? SRTTime.parse(parts[1]) else { continue }
            let textLines = lines[(arrowIndex + 1)...]
            let text = textLines.joined(separator: "\n")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
            entries.append(SRTEntry(start: start.milliseconds,
                                    end: end.milliseconds,
                                    text: text))
        }
        return entries
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter SRTParserTests`
Expected: PASS. (If `count == 6` fails, the sample has a different number of blocks — read the failure, count blocks in `sample.srt`, and correct the expectation to the real count; do not change the parser to force a number.)

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoTaggingCore/SRT/SRTParser.swift Tests/VideoTaggingCoreTests/SRTParserTests.swift
git commit -m "feat(core): tolerant SRT parser"
```

---

### Task 5: SRTWriter — sections to srt (exclude empty, renumber)

**Files:**
- Create: `Sources/VideoTaggingCore/SRT/SRTWriter.swift`
- Test: `Tests/VideoTaggingCoreTests/SRTWriterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
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
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter SRTWriterTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

`Sources/VideoTaggingCore/SRT/SRTWriter.swift`:
```swift
public enum SRTWriter {
    public static func write(_ sections: [Section]) -> String {
        let kept = sections.filter { !$0.isEmpty }
        let blocks = kept.enumerated().map { (i, section) -> String in
            let start = SRTTime(milliseconds: section.start).srtString
            let end = SRTTime(milliseconds: section.end).srtString
            let text = section.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return "\(i + 1)\n\(start) --> \(end)\n\(text)"
        }
        return blocks.joined(separator: "\n\n")
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter SRTWriterTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoTaggingCore/SRT/SRTWriter.swift Tests/VideoTaggingCoreTests/SRTWriterTests.swift
git commit -m "feat(core): SRT writer with empty exclusion and renumbering"
```

---

### Task 6: SectionPartition — invariant + cut/merge/move/normalize

**Files:**
- Create: `Sources/VideoTaggingCore/Partition/SectionPartition.swift`
- Test: `Tests/VideoTaggingCoreTests/SectionPartitionTests.swift`

The partition owns `duration` and a contiguous `[Section]` covering `[0, duration]`.
Minimum section length is `minSectionMs = 200`. All operations preserve the
invariant and become no-ops when they would violate it.

- [ ] **Step 1: Write failing tests**

```swift
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
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter SectionPartitionTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

`Sources/VideoTaggingCore/Partition/SectionPartition.swift`:
```swift
import Foundation

public struct SectionPartition: Equatable, Sendable {
    public static let minSectionMs = 200

    public private(set) var duration: Int
    public var sections: [Section]

    /// Blank partition: one empty section over the whole video.
    public init(duration: Int) {
        self.duration = max(Self.minSectionMs, duration)
        self.sections = [Section(start: 0, end: self.duration, text: "")]
    }

    /// Build a contiguous partition from parsed SRT entries.
    /// Cut points are taken from entry starts; each start aligns to the
    /// previous end so the result is gap/overlap-free. Texts are assigned to
    /// the section their entry starts in (joined if several land together).
    public init(duration: Int, fromEntries entries: [SRTEntry]) {
        let dur = max(Self.minSectionMs, duration)
        let sorted = entries.sorted { $0.start < $1.start }
        guard !sorted.isEmpty else {
            self.init(duration: dur)
            return
        }
        // Candidate internal cut points from entry starts (skip the first).
        var cuts: [Int] = []
        var last = 0
        for entry in sorted.dropFirst() {
            let c = entry.start
            if c > last + Self.minSectionMs && c < dur - Self.minSectionMs {
                cuts.append(c)
                last = c
            }
        }
        // Build boundaries 0 ... cuts ... dur and the sections between them.
        let bounds = [0] + cuts + [dur]
        var built: [Section] = []
        for i in 0..<(bounds.count - 1) {
            built.append(Section(start: bounds[i], end: bounds[i + 1], text: ""))
        }
        // Assign each entry's text to the section whose range contains its start.
        for entry in sorted {
            let idx = built.firstIndex { entry.start >= $0.start && entry.start < $0.end }
                ?? (built.count - 1)
            if built[idx].text.isEmpty {
                built[idx].text = entry.text
            } else if !entry.text.isEmpty {
                built[idx].text += "\n" + entry.text
            }
        }
        self.duration = dur
        self.sections = built
    }

    public func indexContaining(ms: Int) -> Int {
        for (i, s) in sections.enumerated() where ms >= s.start && ms < s.end {
            return i
        }
        return sections.count - 1
    }

    /// Split the section containing `atMs` at that point.
    /// Earlier portion keeps the text; later portion is empty.
    public mutating func cut(atMs: Int) {
        let i = indexContaining(ms: atMs)
        let s = sections[i]
        guard atMs > s.start + Self.minSectionMs,
              atMs < s.end - Self.minSectionMs else { return }
        let earlier = Section(id: s.id, start: s.start, end: atMs, text: s.text)
        let later = Section(start: atMs, end: s.end, text: "")
        sections.replaceSubrange(i...i, with: [earlier, later])
    }

    /// Move the cut that is the start of `beforeIndex` (== end of beforeIndex-1).
    public mutating func moveBoundary(beforeIndex: Int, toMs: Int) {
        guard beforeIndex >= 1, beforeIndex < sections.count else { return }
        let lower = sections[beforeIndex - 1].start + Self.minSectionMs
        let upper = sections[beforeIndex].end - Self.minSectionMs
        guard lower <= upper else { return }
        let clamped = min(max(toMs, lower), upper)
        sections[beforeIndex - 1].end = clamped
        sections[beforeIndex].start = clamped
    }

    /// Remove the cut before `boundaryBeforeIndex`, merging it with the previous
    /// section. Non-empty text wins; both non-empty are joined with newline.
    public mutating func merge(boundaryBeforeIndex i: Int) {
        guard i >= 1, i < sections.count else { return }
        let prev = sections[i - 1]
        let cur = sections[i]
        let mergedText: String
        if prev.text.isEmpty { mergedText = cur.text }
        else if cur.text.isEmpty { mergedText = prev.text }
        else { mergedText = prev.text + "\n" + cur.text }
        let merged = Section(id: prev.id, start: prev.start, end: cur.end, text: mergedText)
        sections.replaceSubrange((i - 1)...i, with: [merged])
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter SectionPartitionTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoTaggingCore/Partition Tests/VideoTaggingCoreTests/SectionPartitionTests.swift
git commit -m "feat(core): contiguous SectionPartition with cut/move/merge/normalize"
```

---

### Task 7: FileKind + FilePairing

**Files:**
- Create: `Sources/VideoTaggingCore/Files/FileKind.swift`
- Create: `Sources/VideoTaggingCore/Files/FilePairing.swift`
- Test: `Tests/VideoTaggingCoreTests/FilePairingTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import Foundation
import Testing
@testable import VideoTaggingCore

@Suite struct FilePairingTests {
    // Injects which sibling files "exist".
    func pairer(existing: Set<String> = []) -> FilePairing {
        FilePairing { url in existing.contains(url.path) }
    }

    @Test func videoWithSiblingSrt() throws {
        let video = URL(fileURLWithPath: "/v/clip.mp4")
        let srt = URL(fileURLWithPath: "/v/clip.srt")
        let result = try pairer(existing: [srt.path]).resolve([video])
        #expect(result.video == video)
        #expect(result.srt == srt)
    }

    @Test func videoWithoutSrtStartsFresh() throws {
        let video = URL(fileURLWithPath: "/v/clip.mp4")
        let result = try pairer().resolve([video])
        #expect(result.video == video)
        #expect(result.srt == nil)
    }

    @Test func srtWithSiblingVideoOpensVideo() throws {
        let srt = URL(fileURLWithPath: "/v/clip.srt")
        let video = URL(fileURLWithPath: "/v/clip.mp4")
        let result = try pairer(existing: [video.path]).resolve([srt])
        #expect(result.video == video)
        #expect(result.srt == srt)
    }

    @Test func srtWithoutVideoErrors() {
        let srt = URL(fileURLWithPath: "/v/clip.srt")
        #expect(throws: FilePairing.PairingError.videoNotFoundForSubtitles) {
            try pairer().resolve([srt])
        }
    }

    @Test func twoFilesPairedRegardlessOfName() throws {
        let video = URL(fileURLWithPath: "/v/movie.mov")
        let srt = URL(fileURLWithPath: "/x/notes.srt")
        let result = try pairer().resolve([video, srt])
        #expect(result.video == video)
        #expect(result.srt == srt)
    }

    @Test func twoVideosErrors() {
        let a = URL(fileURLWithPath: "/v/a.mp4")
        let b = URL(fileURLWithPath: "/v/b.mp4")
        #expect(throws: FilePairing.PairingError.tooManyVideos) {
            try pairer().resolve([a, b])
        }
    }

    @Test func noVideoOrSrtErrors() {
        let other = URL(fileURLWithPath: "/v/file.txt")
        #expect(throws: FilePairing.PairingError.noUsableFiles) {
            try pairer().resolve([other])
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter FilePairingTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

`Sources/VideoTaggingCore/Files/FileKind.swift`:
```swift
import Foundation

public enum FileKind: Equatable, Sendable {
    case video
    case subtitles
    case other

    public static let videoExtensions: Set<String> = ["mp4", "mov", "m4v"]

    public init(url: URL) {
        let ext = url.pathExtension.lowercased()
        if Self.videoExtensions.contains(ext) { self = .video }
        else if ext == "srt" { self = .subtitles }
        else { self = .other }
    }
}
```

`Sources/VideoTaggingCore/Files/FilePairing.swift`:
```swift
import Foundation

public struct FilePairing: Sendable {
    public struct Resolved: Equatable, Sendable {
        public let video: URL
        public let srt: URL?
    }

    public enum PairingError: Error, Equatable {
        case videoNotFoundForSubtitles
        case tooManyVideos
        case noUsableFiles
    }

    private let fileExists: @Sendable (URL) -> Bool

    public init(fileExists: @escaping @Sendable (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) {
        self.fileExists = fileExists
    }

    /// Resolve 1 or 2 dropped/picked URLs into a (video, srt?) pair.
    public func resolve(_ urls: [URL]) throws -> Resolved {
        let videos = urls.filter { FileKind(url: $0) == .video }
        let srts = urls.filter { FileKind(url: $0) == .subtitles }

        if videos.count > 1 { throw PairingError.tooManyVideos }

        if let video = videos.first {
            if let srt = srts.first { return Resolved(video: video, srt: srt) }
            let sibling = video.deletingPathExtension().appendingPathExtension("srt")
            return Resolved(video: video, srt: fileExists(sibling) ? sibling : nil)
        }

        if let srt = srts.first {
            for ext in FileKind.videoExtensions.sorted() {
                let sibling = srt.deletingPathExtension().appendingPathExtension(ext)
                if fileExists(sibling) { return Resolved(video: sibling, srt: srt) }
            }
            throw PairingError.videoNotFoundForSubtitles
        }

        throw PairingError.noUsableFiles
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter FilePairingTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoTaggingCore/Files Tests/VideoTaggingCoreTests/FilePairingTests.swift
git commit -m "feat(core): file kind classification and drop pairing"
```

---

### Task 8: BackupService

**Files:**
- Create: `Sources/VideoTaggingCore/Files/BackupService.swift`
- Test: `Tests/VideoTaggingCoreTests/BackupServiceTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import Foundation
import Testing
@testable import VideoTaggingCore

@Suite struct BackupServiceTests {
    @Test func writesTimestampedCopyInBackupsFolder() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let srt = tmp.appendingPathComponent("clip.srt")
        try "1\n00:00:00,000 --> 00:00:01,000\nhi".write(to: srt, atomically: true, encoding: .utf8)

        let service = BackupService()
        let backup = try service.backup(srt: srt, timestamp: "20260603-101500")

        #expect(backup.lastPathComponent == "clip.20260603-101500.srt")
        #expect(backup.deletingLastPathComponent().lastPathComponent == ".backups")
        #expect(FileManager.default.fileExists(atPath: backup.path))
        let restored = try String(contentsOf: backup, encoding: .utf8)
        #expect(restored.contains("hi"))
    }

    @Test func backingUpMissingFileIsNoOp() throws {
        let missing = URL(fileURLWithPath: "/nope/clip.srt")
        let result = try BackupService().backupIfExists(srt: missing, timestamp: "t")
        #expect(result == nil)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter BackupServiceTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

`Sources/VideoTaggingCore/Files/BackupService.swift`:
```swift
import Foundation

public struct BackupService: Sendable {
    public init() {}

    /// Copy `srt` into a sibling `.backups/` folder as `<name>.<timestamp>.srt`.
    @discardableResult
    public func backup(srt: URL, timestamp: String) throws -> URL {
        let folder = srt.deletingLastPathComponent().appendingPathComponent(".backups")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = srt.deletingPathExtension().lastPathComponent
        let dest = folder.appendingPathComponent("\(name).\(timestamp).srt")
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: srt, to: dest)
        return dest
    }

    @discardableResult
    public func backupIfExists(srt: URL, timestamp: String) throws -> URL? {
        guard FileManager.default.fileExists(atPath: srt.path) else { return nil }
        return try backup(srt: srt, timestamp: timestamp)
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter BackupServiceTests`
Expected: PASS.

- [ ] **Step 5: Run the whole core suite and commit**

Run: `swift test`
Expected: all tests PASS.

```bash
git add Sources/VideoTaggingCore/Files/BackupService.swift Tests/VideoTaggingCoreTests/BackupServiceTests.swift
git commit -m "feat(core): timestamped srt backups"
```

---

# PHASE 2 — Video player + editing + auto-save (SwiftUI app)

> Phase 2 produces a launchable app that opens a hardcoded video+srt (wired
> properly in Phase 3), plays it, and lets the user cut/move/merge/edit with
> auto-save. UI is verified by building and launching (`swift run`); the
> ViewModel's pure logic is unit-tested in the app target where practical.

### Task 9: Theme, Strings, BigButton, TimeLabel

**Files:**
- Create: `Sources/VideoTagging/Theme/Theme.swift`
- Create: `Sources/VideoTagging/Constants/Strings.swift`
- Create: `Sources/VideoTagging/Components/BigButton.swift`
- Create: `Sources/VideoTagging/Components/TimeLabel.swift`

- [ ] **Step 1: Theme**

`Sources/VideoTagging/Theme/Theme.swift`:
```swift
import SwiftUI

enum Theme {
    enum Colors {
        static let accent = Color(red: 0.18, green: 0.42, blue: 0.87)
        static let panel = Color(white: 0.15)
        static let panelBorder = Color(white: 0.32)
        static let gapSection = Color(red: 0.35, green: 0.29, blue: 0.16)
        static let textPrimary = Color.white
        static let textSecondary = Color(white: 0.7)
    }
    enum Fonts {
        static let title = Font.system(size: 22, weight: .semibold)
        static let body = Font.system(size: 22)
        static let button = Font.system(size: 20, weight: .semibold)
        static let time = Font.system(size: 26, weight: .medium).monospacedDigit()
        static let label = Font.system(size: 15, weight: .semibold)
    }
    enum Spacing {
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
    }
}
```

- [ ] **Step 2: Strings**

`Sources/VideoTagging/Constants/Strings.swift`:
```swift
enum Strings {
    static let appName = "Video Section Tagger"
    static let cutHere = "Cut here"
    static let moveStartBack = "◀ Move start"
    static let moveStartForward = "Move start ▶"
    static let moveEndBack = "◀ Move end"
    static let moveEndForward = "Move end ▶"
    static let mergeWithPrevious = "Merge / delete cut"
    static let descriptionPlaceholder = "Describe what is shown here…"
    static let saved = "Saved ✓"
    static let saving = "Saving…"
    static let saveFailed = "Could not save"
    static let showList = "Show list"
    static let hideList = "Hide list"
    static let previousSection = "Previous"
    static let nextSection = "Next"

    enum DropZone {
        static let title = "Drop a video here"
        static let subtitle = "Drop a video (and optionally its .srt), or click to choose files."
        static let videoNotFound = "I found the subtitles but not the video next to them. Drop the video too, or click to pick both files."
        static let tooManyVideos = "Please drop only one video at a time."
        static let noUsable = "That doesn't look like a video or a .srt file. Try again."
    }
}
```

- [ ] **Step 3: BigButton**

`Sources/VideoTagging/Components/BigButton.swift`:
```swift
import SwiftUI

struct BigButton: View {
    let title: String
    var prominent: Bool = false
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(Theme.Fonts.button)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: prominent ? .infinity : nil)
            .foregroundStyle(prominent ? Color.white : Theme.Colors.textPrimary)
            .background(prominent ? Theme.Colors.accent : Theme.Colors.panel)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 4: TimeLabel**

`Sources/VideoTagging/Components/TimeLabel.swift`:
```swift
import SwiftUI
import VideoTaggingCore

struct TimeLabel: View {
    let currentMs: Int
    let totalMs: Int
    var body: some View {
        Text("\(SRTTime(milliseconds: currentMs).displayString) / \(SRTTime(milliseconds: totalMs).displayString)")
            .font(Theme.Fonts.time)
            .foregroundStyle(Theme.Colors.textPrimary)
    }
}
```

- [ ] **Step 5: Build and commit**

Run: `swift build`
Expected: `Build complete!`
```bash
git add Sources/VideoTagging/Theme Sources/VideoTagging/Constants Sources/VideoTagging/Components
git commit -m "feat(app): theme, strings, BigButton, TimeLabel"
```

---

### Task 10: EditorViewModel — state, playback, editing, autosave wiring

**Files:**
- Create: `Sources/VideoTagging/State/EditorViewModel.swift`
- Create: `Sources/VideoTagging/Services/AutosaveService.swift`
- Test: `Tests/VideoTaggingCoreTests/` is for Core; for the VM add a lightweight
  app-target test is not possible without a test target on the app. Keep VM
  editing logic delegating to Core (already tested). Verify by build + launch.

- [ ] **Step 1: AutosaveService (debounced write)**

`Sources/VideoTagging/Services/AutosaveService.swift`:
```swift
import Foundation
import VideoTaggingCore

/// Debounced writer: coalesces rapid edits into one write after a short delay.
@MainActor
final class AutosaveService {
    enum Status: Equatable { case idle, saving, saved, failed(String) }

    private(set) var status: Status = .saved
    private var pending: Task<Void, Never>?
    private let debounce: Duration

    init(debounce: Duration = .milliseconds(600)) { self.debounce = debounce }

    func scheduleSave(sections: [Section], to url: URL, onStatus: @escaping (Status) -> Void) {
        pending?.cancel()
        onStatus(.saving)
        status = .saving
        pending = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            if Task.isCancelled { return }
            let text = SRTWriter.write(sections)
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                self.status = .saved
                onStatus(.saved)
            } catch {
                self.status = .failed(error.localizedDescription)
                onStatus(.failed(error.localizedDescription))
            }
        }
    }
}
```

- [ ] **Step 2: EditorViewModel**

`Sources/VideoTagging/State/EditorViewModel.swift`:
```swift
import Foundation
import AVKit
import Observation
import VideoTaggingCore

@MainActor
@Observable
final class EditorViewModel {
    let videoURL: URL
    let srtURL: URL
    let player: AVPlayer

    var partition: SectionPartition
    var currentIndex: Int = 0
    var currentMs: Int = 0
    var totalMs: Int = 0
    var isListVisible: Bool = false
    var saveStatus: AutosaveService.Status = .saved

    private let autosave = AutosaveService()
    private var timeObserver: Any?

    init(videoURL: URL, srtURL: URL, partition: SectionPartition) {
        self.videoURL = videoURL
        self.srtURL = srtURL
        self.partition = partition
        self.totalMs = partition.duration
        self.player = AVPlayer(url: videoURL)
        observePlayhead()
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
    }

    private func observePlayhead() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentMs = Int(time.seconds * 1000)
            self.currentIndex = self.partition.indexContaining(ms: self.currentMs)
        }
    }

    var currentSection: Section { partition.sections[currentIndex] }

    // MARK: Playback
    func togglePlay() {
        player.timeControlStatus == .playing ? player.pause() : player.play()
    }
    func seek(toMs ms: Int) {
        let clamped = min(max(ms, 0), totalMs)
        player.seek(to: CMTime(value: CMTimeValue(clamped), timescale: 1000),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        currentMs = clamped
    }
    func jog(byMs delta: Int) { seek(toMs: currentMs + delta) }

    // MARK: Navigation
    func goToSection(_ index: Int) {
        guard partition.sections.indices.contains(index) else { return }
        currentIndex = index
        seek(toMs: partition.sections[index].start)
    }
    func previousSection() { goToSection(currentIndex - 1) }
    func nextSection() { goToSection(currentIndex + 1) }

    // MARK: Editing (delegates to Core, then saves)
    func cutHere() {
        partition.cut(atMs: currentMs)
        currentIndex = partition.indexContaining(ms: currentMs)
        save()
    }
    func moveStart(byMs delta: Int) {
        guard currentIndex >= 1 else { return }
        partition.moveBoundary(beforeIndex: currentIndex,
                               toMs: partition.sections[currentIndex].start + delta)
        save()
    }
    func moveEnd(byMs delta: Int) {
        let boundary = currentIndex + 1
        guard boundary < partition.sections.count else { return }
        partition.moveBoundary(beforeIndex: boundary,
                               toMs: partition.sections[currentIndex].end + delta)
        save()
    }
    func mergeWithPrevious() {
        guard currentIndex >= 1 else { return }
        partition.merge(boundaryBeforeIndex: currentIndex)
        currentIndex = max(0, currentIndex - 1)
        save()
    }
    func updateCurrentText(_ text: String) {
        partition.sections[currentIndex].text = text
        save()
    }

    func save() {
        autosave.scheduleSave(sections: partition.sections, to: srtURL) { [weak self] status in
            self?.saveStatus = status
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Sources/VideoTagging/State Sources/VideoTagging/Services
git commit -m "feat(app): EditorViewModel and debounced autosave"
```

---

### Task 11: SectionCardView, TransportBar, EditorView, app entry (launchable)

**Files:**
- Create: `Sources/VideoTagging/Features/Editor/SectionCardView.swift`
- Create: `Sources/VideoTagging/Features/Editor/TransportBar.swift`
- Create: `Sources/VideoTagging/Features/Editor/EditorView.swift`
- Modify: `Sources/VideoTagging/VideoTaggingApp.swift`

- [ ] **Step 1: TransportBar**

`Sources/VideoTagging/Features/Editor/TransportBar.swift`:
```swift
import SwiftUI

struct TransportBar: View {
    let isPlaying: Bool
    let currentMs: Int
    let totalMs: Int
    let onTogglePlay: () -> Void
    let onScrub: (Int) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button(action: onTogglePlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26))
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.white)
                    .background(Theme.Colors.accent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Slider(
                value: Binding(
                    get: { Double(currentMs) },
                    set: { onScrub(Int($0)) }
                ),
                in: 0...Double(max(totalMs, 1))
            )
            TimeLabel(currentMs: currentMs, totalMs: totalMs)
        }
    }
}
```

- [ ] **Step 2: SectionCardView**

`Sources/VideoTagging/Features/Editor/SectionCardView.swift`:
```swift
import SwiftUI
import VideoTaggingCore

struct SectionCardView: View {
    let index: Int
    let section: Section
    let canMoveStart: Bool
    let canMoveEnd: Bool
    let canMerge: Bool
    let text: Binding<String>
    let onCut: () -> Void
    let onMoveStart: (Int) -> Void
    let onMoveEnd: (Int) -> Void
    let onMerge: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("SECTION \(index + 1)  ·  \(SRTTime(milliseconds: section.start).displayString) – \(SRTTime(milliseconds: section.end).displayString)")
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textSecondary)

            TextEditor(text: text)
                .font(Theme.Fonts.body)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(white: 0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            BigButton(title: Strings.cutHere, prominent: true, systemImage: "scissors", action: onCut)

            HStack(spacing: Theme.Spacing.s) {
                if canMoveStart {
                    BigButton(title: Strings.moveStartBack) { onMoveStart(-1000) }
                    BigButton(title: Strings.moveStartForward) { onMoveStart(1000) }
                }
                if canMoveEnd {
                    BigButton(title: Strings.moveEndBack) { onMoveEnd(-1000) }
                    BigButton(title: Strings.moveEndForward) { onMoveEnd(1000) }
                }
            }
            if canMerge {
                BigButton(title: Strings.mergeWithPrevious, systemImage: "arrow.triangle.merge", action: onMerge)
            }
        }
        .padding(Theme.Spacing.m)
        .background(Theme.Colors.panel)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.accent, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 3: EditorView (timeline + list panel added in Phase 4; leave placeholders wired)**

`Sources/VideoTagging/Features/Editor/EditorView.swift`:
```swift
import SwiftUI
import AVKit
import VideoTaggingCore

struct EditorView: View {
    @Bindable var vm: EditorViewModel
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.m) {
                VideoPlayer(player: vm.player)
                    .frame(minHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                TransportBar(
                    isPlaying: isPlaying,
                    currentMs: vm.currentMs,
                    totalMs: vm.totalMs,
                    onTogglePlay: { vm.togglePlay(); isPlaying.toggle() },
                    onScrub: { vm.seek(toMs: $0) }
                )

                SectionCardView(
                    index: vm.currentIndex,
                    section: vm.currentSection,
                    canMoveStart: vm.currentIndex >= 1,
                    canMoveEnd: vm.currentIndex + 1 < vm.partition.sections.count,
                    canMerge: vm.currentIndex >= 1,
                    text: Binding(
                        get: { vm.currentSection.text },
                        set: { vm.updateCurrentText($0) }
                    ),
                    onCut: vm.cutHere,
                    onMoveStart: vm.moveStart(byMs:),
                    onMoveEnd: vm.moveEnd(byMs:),
                    onMerge: vm.mergeWithPrevious
                )

                SaveStatusLabel(status: vm.saveStatus)
                Spacer()
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color(white: 0.1))
    }
}

struct SaveStatusLabel: View {
    let status: AutosaveService.Status
    var body: some View {
        let (text, color): (String, Color) = switch status {
            case .saved: (Strings.saved, Theme.Colors.textSecondary)
            case .saving: (Strings.saving, Theme.Colors.textSecondary)
            case .idle: ("", .clear)
            case .failed(let m): ("\(Strings.saveFailed): \(m)", .red)
        }
        Text(text).font(Theme.Fonts.label).foregroundStyle(color)
    }
}
```

- [ ] **Step 4: App entry — temporary direct-load of the sample for launch testing**

`Sources/VideoTagging/VideoTaggingApp.swift`:
```swift
import SwiftUI
import AppKit
import VideoTaggingCore

@main
struct VideoTaggingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup(Strings.appName) {
            RootView()
                .frame(minWidth: 900, minHeight: 700)
        }
        .windowStyle(.titleBar)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

// Temporary root for Phase 2 launch verification; replaced by AppRouter in Phase 3.
struct RootView: View {
    @State private var vm: EditorViewModel?

    var body: some View {
        Group {
            if let vm { EditorView(vm: vm) }
            else { Text("Set VIDEO_TAGGER_SAMPLE to a video path to test.").padding() }
        }
        .task { await load() }
    }

    @MainActor private func load() async {
        guard vm == nil,
              let path = ProcessInfo.processInfo.environment["VIDEO_TAGGER_SAMPLE"] else { return }
        let video = URL(fileURLWithPath: path)
        let srt = video.deletingPathExtension().appendingPathExtension("srt")
        let durationMs = await videoDurationMs(video)
        let partition: SectionPartition
        if let content = try? String(contentsOf: srt, encoding: .utf8) {
            partition = SectionPartition(duration: durationMs, fromEntries: SRTParser.parse(content))
        } else {
            partition = SectionPartition(duration: durationMs)
        }
        vm = EditorViewModel(videoURL: video, srtURL: srt, partition: partition)
    }
}
```

Add a helper for duration in `EditorViewModel.swift` (append at file end):
```swift
import AVFoundation

func videoDurationMs(_ url: URL) async -> Int {
    let asset = AVURLAsset(url: url)
    let duration = (try? await asset.load(.duration)) ?? .zero
    return max(1, Int(duration.seconds * 1000))
}
```

- [ ] **Step 5: Build**

Run: `swift build`
Expected: `Build complete!`

- [ ] **Step 6: Launch and verify manually**

Run:
```bash
VIDEO_TAGGER_SAMPLE="$PWD/sample.mp4" swift run VideoTagging
```
Expected: a window opens, the video plays, the current-section card shows the
description, Cut/Move/Merge work, the `.srt` is rewritten on edit (check
`git diff "sample.srt"` — but note that file is gitignored; open
it to confirm changes). Close the window to exit.

- [ ] **Step 7: Commit**

```bash
git add Sources/VideoTagging
git commit -m "feat(app): editor view, transport, section card, launchable app"
```

---

# PHASE 3 — Drop zone, file pairing wiring, errors, backup-on-open

### Task 12: AppRouter + DropZoneView + open flow with backup

**Files:**
- Create: `Sources/VideoTagging/State/AppRouter.swift`
- Create: `Sources/VideoTagging/Features/DropZone/DropZoneView.swift`
- Modify: `Sources/VideoTagging/VideoTaggingApp.swift` (replace RootView with router)

- [ ] **Step 1: AppRouter — owns open logic, errors, backup, partition building**

`Sources/VideoTagging/State/AppRouter.swift`:
```swift
import Foundation
import Observation
import VideoTaggingCore

@MainActor
@Observable
final class AppRouter {
    enum Screen { case dropZone, editor(EditorViewModel) }
    var screen: Screen = .dropZone
    var errorMessage: String?

    private let pairing = FilePairing()
    private let backups = BackupService()

    func open(urls: [URL]) {
        errorMessage = nil
        do {
            let resolved = try pairing.resolve(urls)
            Task { await openResolved(resolved) }
        } catch let e as FilePairing.PairingError {
            errorMessage = message(for: e)
        } catch {
            errorMessage = Strings.DropZone.noUsable
        }
    }

    private func openResolved(_ resolved: FilePairing.Resolved) async {
        let durationMs = await videoDurationMs(resolved.video)
        let srtURL = resolved.srt
            ?? resolved.video.deletingPathExtension().appendingPathExtension("srt")

        var partition = SectionPartition(duration: durationMs)
        if let srt = resolved.srt,
           let content = try? String(contentsOf: srt, encoding: .utf8) {
            try? backups.backupIfExists(srt: srt, timestamp: Self.timestamp())
            partition = SectionPartition(duration: durationMs,
                                         fromEntries: SRTParser.parse(content))
        }
        screen = .editor(EditorViewModel(videoURL: resolved.video,
                                         srtURL: srtURL,
                                         partition: partition))
    }

    private func message(for error: FilePairing.PairingError) -> String {
        switch error {
        case .videoNotFoundForSubtitles: Strings.DropZone.videoNotFound
        case .tooManyVideos: Strings.DropZone.tooManyVideos
        case .noUsableFiles: Strings.DropZone.noUsable
        }
    }

    static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}
```

- [ ] **Step 2: DropZoneView**

`Sources/VideoTagging/Features/DropZone/DropZoneView.swift`:
```swift
import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    let onOpen: ([URL]) -> Void
    let errorMessage: String?
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Colors.textSecondary)
            Text(Strings.DropZone.title).font(.system(size: 30, weight: .semibold))
            Text(Strings.DropZone.subtitle)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            if let errorMessage {
                Text(errorMessage)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.top, Theme.Spacing.s)
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? Theme.Colors.accent.opacity(0.15) : Color(white: 0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [10]))
                .foregroundStyle(Theme.Colors.panelBorder)
        )
        .contentShape(Rectangle())
        .onTapGesture { pickFiles() }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            collectURLs(from: providers); return true
        }
        .padding(Theme.Spacing.l)
    }

    private func collectURLs(from providers: [NSItemProvider]) {
        var urls: [URL] = []
        let group = DispatchGroup()
        for p in providers.prefix(2) {
            group.enter()
            _ = p.loadObject(ofClass: URL.self) { url, _ in
                if let url { urls.append(url) }
                group.leave()
            }
        }
        group.notify(queue: .main) { if !urls.isEmpty { onOpen(urls) } }
    }

    private func pickFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie,
                                     UTType(filenameExtension: "srt") ?? .plainText]
        if panel.runModal() == .OK {
            onOpen(Array(panel.urls.prefix(2)))
        }
    }
}
```

- [ ] **Step 3: Wire router into the app**

Replace `RootView` in `VideoTaggingApp.swift` with:
```swift
struct RootView: View {
    @State private var router = AppRouter()
    var body: some View {
        switch router.screen {
        case .dropZone:
            DropZoneView(onOpen: { router.open(urls: $0) }, errorMessage: router.errorMessage)
        case .editor(let vm):
            EditorView(vm: vm)
        }
    }
}
```
Delete the temporary `load()`/`VIDEO_TAGGER_SAMPLE` code from Phase 2.

- [ ] **Step 4: Build, launch, verify drop + pick + error message**

Run: `swift build` → `swift run VideoTagging`
Expected: drop zone shows; dropping the sample `.mp4` opens the editor with the
existing `.srt` loaded; dropping only the `.srt` after moving the video away
shows the friendly "video not found" message; a `.backups/` folder appears next
to the `.srt`.

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoTagging
git commit -m "feat(app): drop zone, file pairing, friendly errors, backup on open"
```

---

# PHASE 4 — Timeline, list panel, keyboard shortcuts, polish

### Task 13: TimelineView (blocks + handles + nav arrows)

**Files:**
- Create: `Sources/VideoTagging/Features/Editor/TimelineView.swift`
- Modify: `Sources/VideoTagging/Features/Editor/EditorView.swift`

- [ ] **Step 1: TimelineView**

`Sources/VideoTagging/Features/Editor/TimelineView.swift`:
```swift
import SwiftUI
import VideoTaggingCore

struct TimelineView: View {
    let sections: [Section]
    let totalMs: Int
    let currentIndex: Int
    let onSelect: (Int) -> Void
    let onDragBoundary: (_ beforeIndex: Int, _ toMs: Int) -> Void

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            func x(_ ms: Int) -> CGFloat { CGFloat(ms) / CGFloat(max(totalMs, 1)) * width }

            ZStack(alignment: .leading) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { i, s in
                    let left = x(s.start)
                    let w = max(2, x(s.end) - left)
                    Rectangle()
                        .fill(color(for: s, isCurrent: i == currentIndex))
                        .frame(width: w)
                        .offset(x: left)
                        .onTapGesture { onSelect(i) }
                }
                // Draggable handles at internal boundaries
                ForEach(1..<max(sections.count, 1), id: \.self) { i in
                    let bx = x(sections[i].start)
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 3)
                        .offset(x: bx - 1.5)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let ms = Int(value.location.x / width * CGFloat(totalMs))
                                    onDragBoundary(i, ms)
                                }
                        )
                }
            }
        }
        .frame(height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func color(for s: Section, isCurrent: Bool) -> Color {
        if isCurrent { return Theme.Colors.accent }
        return s.isEmpty ? Theme.Colors.gapSection : Theme.Colors.panel
    }
}
```

- [ ] **Step 2: Add timeline + nav arrows to EditorView**

In `EditorView.swift`, insert below `SaveStatusLabel(...)`:
```swift
HStack(spacing: Theme.Spacing.s) {
    Button { vm.previousSection() } label: { Image(systemName: "chevron.left").font(.system(size: 24)) }
        .buttonStyle(.plain)
    TimelineView(
        sections: vm.partition.sections,
        totalMs: vm.totalMs,
        currentIndex: vm.currentIndex,
        onSelect: { vm.goToSection($0) },
        onDragBoundary: { beforeIndex, toMs in
            vm.partition.moveBoundary(beforeIndex: beforeIndex, toMs: toMs)
            vm.save()
        }
    )
    Button { vm.nextSection() } label: { Image(systemName: "chevron.right").font(.system(size: 24)) }
        .buttonStyle(.plain)
}
```

- [ ] **Step 3: Build, launch, verify timeline blocks/drag/nav**

Run: `swift build` → `swift run VideoTagging` (open the sample)
Expected: blocks render, current is highlighted, empty sections are a distinct
color, dragging a handle moves the boundary, arrows change the current section.

- [ ] **Step 4: Commit**

```bash
git add Sources/VideoTagging/Features/Editor
git commit -m "feat(app): timeline with blocks, draggable handles, nav arrows"
```

---

### Task 14: SectionListPanel (hideable side panel)

**Files:**
- Create: `Sources/VideoTagging/Features/SectionList/SectionListPanel.swift`
- Modify: `Sources/VideoTagging/Features/Editor/EditorView.swift`

- [ ] **Step 1: SectionListPanel**

`Sources/VideoTagging/Features/SectionList/SectionListPanel.swift`:
```swift
import SwiftUI
import VideoTaggingCore

struct SectionListPanel: View {
    let sections: [Section]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { i, s in
                    Button { onSelect(i) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(i + 1) · \(SRTTime(milliseconds: s.start).displayString)–\(SRTTime(milliseconds: s.end).displayString)")
                                .font(Theme.Fonts.label)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Text(s.isEmpty ? Strings.descriptionPlaceholder : s.text)
                                .font(.system(size: 17))
                                .foregroundStyle(s.isEmpty ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(i == currentIndex ? Theme.Colors.accent.opacity(0.25) : Theme.Colors.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .frame(width: 320)
        .background(Color(white: 0.08))
    }
}
```

- [ ] **Step 2: Add toggle + panel to EditorView**

Wrap the editor body so the panel shows when `vm.isListVisible`. Replace the
outer `HStack(spacing: 0) { ... }` content so it becomes:
```swift
HStack(spacing: 0) {
    VStack(spacing: Theme.Spacing.m) {
        HStack {
            Spacer()
            BigButton(title: vm.isListVisible ? Strings.hideList : Strings.showList,
                      systemImage: "sidebar.right") { vm.isListVisible.toggle() }
        }
        // ... existing video / transport / card / save / timeline ...
    }
    .padding(Theme.Spacing.l)

    if vm.isListVisible {
        SectionListPanel(sections: vm.partition.sections,
                         currentIndex: vm.currentIndex,
                         onSelect: { vm.goToSection($0) })
    }
}
```

- [ ] **Step 3: Build, launch, verify panel toggles and navigates**

Run: `swift build` → `swift run VideoTagging`
Expected: a "Show list / Hide list" button toggles a right-hand list; clicking a
row jumps to that section.

- [ ] **Step 4: Commit**

```bash
git add Sources/VideoTagging/Features
git commit -m "feat(app): hideable section list side panel"
```

---

### Task 15: Keyboard shortcuts + help

**Files:**
- Modify: `Sources/VideoTagging/Features/Editor/EditorView.swift`
- Create: `Sources/VideoTagging/Features/Editor/ShortcutsHelp.swift`

- [ ] **Step 1: ShortcutsHelp sheet**

`Sources/VideoTagging/Features/Editor/ShortcutsHelp.swift`:
```swift
import SwiftUI

struct ShortcutsHelp: View {
    let onClose: () -> Void
    private let rows: [(String, String)] = [
        ("Space", "Play / Pause"),
        ("← / →", "Jog 5 seconds"),
        ("Shift ← / →", "Jog 1 second"),
        ("C or Return", "Cut here"),
        ("↑ / ↓", "Previous / Next section"),
        (", / .", "Move end 1s back / forward"),
        ("Shift , / .", "Move start 1s back / forward"),
        ("Esc", "Leave the text field"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Keyboard shortcuts").font(.system(size: 26, weight: .semibold))
            ForEach(rows, id: \.0) { key, desc in
                HStack {
                    Text(key).font(Theme.Fonts.time).frame(width: 160, alignment: .leading)
                    Text(desc).font(Theme.Fonts.body)
                }
            }
            BigButton(title: "Close", action: onClose)
        }
        .padding(Theme.Spacing.l)
        .frame(minWidth: 480)
    }
}
```

- [ ] **Step 2: Attach shortcuts in EditorView**

Add state and modifiers to the top-level view of `EditorView`. After
`.background(Color(white: 0.1))` add:
```swift
.focusable()
.focusEffectDisabled()
.onKeyPress(.space) { vm.togglePlay(); isPlaying.toggle(); return .handled }
.onKeyPress(.leftArrow) { vm.jog(byMs: -5000); return .handled }
.onKeyPress(.rightArrow) { vm.jog(byMs: 5000); return .handled }
.onKeyPress(keys: ["c", "\r"]) { _ in vm.cutHere(); return .handled }
.onKeyPress(.upArrow) { vm.previousSection(); return .handled }
.onKeyPress(.downArrow) { vm.nextSection(); return .handled }
.onKeyPress(keys: [",", "."]) { press in
    let delta = press.key.character == "," ? -1000 : 1000
    if press.modifiers.contains(.shift) { vm.moveStart(byMs: delta) }
    else { vm.moveEnd(byMs: delta) }
    return .handled
}
.toolbar {
    ToolbarItem {
        Button { showHelp = true } label: { Image(systemName: "questionmark.circle") }
    }
}
.sheet(isPresented: $showHelp) { ShortcutsHelp { showHelp = false } }
```
Add `@State private var showHelp = false` near `@State private var isPlaying`.
Note: Shift+arrow jog (1s) — also handle via the `.leftArrow/.rightArrow`
closures by checking modifiers; replace those two closures with:
```swift
.onKeyPress(.leftArrow) { p in vm.jog(byMs: p.modifiers.contains(.shift) ? -1000 : -5000); return .handled }
.onKeyPress(.rightArrow) { p in vm.jog(byMs: p.modifiers.contains(.shift) ? 1000 : 5000); return .handled }
```

- [ ] **Step 3: Build, launch, verify shortcuts and help sheet**

Run: `swift build` → `swift run VideoTagging`
Expected: keys work as listed; the `?` toolbar button shows the help sheet.
(If a key is swallowed while the description `TextEditor` is focused, that is
expected — `Esc` leaves the field first.)

- [ ] **Step 4: Commit**

```bash
git add Sources/VideoTagging/Features/Editor
git commit -m "feat(app): keyboard shortcuts and help sheet"
```

---

### Task 16: Final polish pass + full verification

**Files:**
- Modify: as needed across `Sources/VideoTagging`

- [ ] **Step 1: Run the full core test suite**

Run: `swift test`
Expected: all PASS.

- [ ] **Step 2: Build release and launch once more**

Run: `swift build -c release` then `swift run -c release VideoTagging`
Expected: drop the sample, exercise cut/move/merge/edit/timeline/list/shortcuts,
confirm the `.srt` updates and the save indicator cycles Saving… → Saved ✓.

- [ ] **Step 3: Round-trip integrity check**

Open the sample, make no edits, confirm the on-disk `.srt` still parses to the
same number of non-empty sections (the writer renumbers but content is stable).

- [ ] **Step 4: Commit any polish**

```bash
git add -A
git commit -m "chore(app): phase 1-4 polish and verification"
```

---

## Notes for the implementer

- Phase 5 (scene-change detection + magnetic snapping) is intentionally NOT in
  this plan. It will be a separate, revertable layer added after phases 1–4 are
  validated with the real user.
- The end user's macOS version is unconfirmed; deployment target is macOS 14. If
  their Mac is older, lower `platforms` in `Package.swift` and re-test.
- `onKeyPress` APIs require macOS 14+. If targeting lower, replace with an
  `NSEvent` local monitor.
- All UI copy lives in `Strings.swift`; all colors/fonts in `Theme.swift`. Do not
  hardcode either in views.
