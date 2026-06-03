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
