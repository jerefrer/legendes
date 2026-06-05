import SwiftUI
import Combine
import Sparkle

/// Wraps Sparkle's updater. Sparkle reads `SUFeedURL` and `SUPublicEDKey` from
/// the bundle's Info.plist; with automatic checks enabled it looks for updates
/// in the background and prompts the user. `start()` is wrapped in try? so a
/// dev build run via `swift run` (no Info.plist / no feed) doesn't crash.
@MainActor
final class UpdaterViewModel: ObservableObject {
    private let updater: SPUUpdater
    @Published var canCheckForUpdates = false

    init() {
        let driver = SPUStandardUserDriver(hostBundle: .main, delegate: nil)
        updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: nil)
        do { try updater.start() } catch { /* not configured (e.g. local dev build) */ }
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() { updater.checkForUpdates() }
}

/// The "Check for Updates…" menu item (added under the app menu).
struct CheckForUpdatesCommand: View {
    @ObservedObject var model: UpdaterViewModel
    var body: some View {
        Button(Strings.checkForUpdates) { model.checkForUpdates() }
            .disabled(!model.canCheckForUpdates)
    }
}
