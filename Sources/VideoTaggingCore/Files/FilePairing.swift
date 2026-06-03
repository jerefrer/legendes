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
