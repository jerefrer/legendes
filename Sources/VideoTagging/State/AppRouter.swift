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

    // Fix 4: track the in-flight open task so a new drop cancels the prior one.
    @ObservationIgnored private var openTask: Task<Void, Never>?

    func open(urls: [URL]) {
        errorMessage = nil
        do {
            let resolved = try pairing.resolve(urls)
            // Fix 4: cancel any prior in-flight open before starting a new one.
            openTask?.cancel()
            openTask = Task { await openResolved(resolved) }
        } catch let e as FilePairing.PairingError {
            errorMessage = message(for: e)
        } catch {
            errorMessage = Strings.DropZone.noUsable
        }
    }

    private func openResolved(_ resolved: FilePairing.Resolved) async {
        let durationMs = await videoDurationMs(resolved.video)
        // Fix 2: guard against unreadable video (AVFoundation returns ~0, clamped to 1).
        guard durationMs > 1 else {
            screen = .dropZone
            errorMessage = Strings.DropZone.videoUnreadable
            return
        }

        let srtURL = resolved.srt
            ?? resolved.video.deletingPathExtension().appendingPathExtension("srt")

        var partition = SectionPartition(duration: durationMs)
        if let srt = resolved.srt,
           let content = try? String(contentsOf: srt, encoding: .utf8) {
            // Fix 3: explicit discard so the compiler sees intentional fire-and-forget.
            _ = try? backups.backupIfExists(srt: srt, timestamp: Self.timestamp())
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

    // Fix 5: static DateFormatter — created once, reused on every call.
    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f
    }()

    static func timestamp() -> String {
        timestampFormatter.string(from: Date())
    }
}
