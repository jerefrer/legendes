import Foundation
import VideoTaggingCore

/// Debounced writer: coalesces rapid edits into one write after a short delay.
@MainActor
final class AutosaveService {
    enum Status: Equatable { case idle, saving, saved, failed(String) }

    private(set) var status: Status = .saved
    private var pending: Task<Void, Never>?
    private let debounce: Duration

    // Pending payload so flushNow() can write synchronously if the debounce hasn't fired yet.
    private var pendingSections: [Section]?
    private var pendingURL: URL?
    private var onStatusCallback: ((Status) -> Void)?

    init(debounce: Duration = .milliseconds(600)) { self.debounce = debounce }

    func scheduleSave(sections: [Section], to url: URL, onStatus: @escaping (Status) -> Void) {
        pending?.cancel()
        onStatus(.saving)
        status = .saving
        // Record the pending payload before the debounce so flushNow() can use it.
        pendingSections = sections
        pendingURL = url
        onStatusCallback = onStatus
        pending = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            if Task.isCancelled { return }
            let text = SRTWriter.write(sections)
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                self.status = .saved
                onStatus(.saved)
                self.pending = nil
                self.pendingSections = nil
                self.pendingURL = nil
            } catch {
                self.status = .failed(error.localizedDescription)
                onStatus(.failed(error.localizedDescription))
                self.pending = nil
            }
        }
    }

    /// Cancels the pending debounce task and writes synchronously.
    /// Safe to call when the app is about to terminate.
    func flushNow() {
        pending?.cancel()
        pending = nil
        guard let sections = pendingSections, let url = pendingURL else { return }
        let text = SRTWriter.write(sections)
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            status = .saved
            onStatusCallback?(.saved)
        } catch {
            status = .failed(error.localizedDescription)
            onStatusCallback?(.failed(error.localizedDescription))
        }
        pendingSections = nil
        pendingURL = nil
    }
}
