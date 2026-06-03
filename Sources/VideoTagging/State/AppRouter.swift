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
