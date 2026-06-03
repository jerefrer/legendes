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
