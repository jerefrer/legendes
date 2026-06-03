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
