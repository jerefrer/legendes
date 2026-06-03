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
            self.duration = dur
            self.sections = [Section(start: 0, end: dur, text: "")]
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
