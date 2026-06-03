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
