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
