import SwiftUI
import AppKit
import VideoTaggingCore

// C1: app-level holder so AppDelegate can flush the active editor's pending save.
enum PendingSaveFlusher {
    @MainActor static var flush: () -> Void = {}
}

@main
struct VideoTaggingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var settings = AppSettings()
    @StateObject private var updater = UpdaterViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 1160, minHeight: 780)
                .environment(settings)
                .onChange(of: settings.appearance, initial: true) { _, mode in
                    NSApp.appearance = mode.nsAppearance
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesCommand(model: updater)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) {
        // Flush any pending debounced autosave before the process exits.
        // applicationWillTerminate is always called on the main thread,
        // which satisfies the @MainActor isolation of PendingSaveFlusher.flush.
        PendingSaveFlusher.flush()
    }
}

struct RootView: View {
    @State private var router = AppRouter()

    var body: some View {
        Group {
            switch router.screen {
            case .dropZone:
                DropZoneView(onOpen: { router.open(urls: $0) }, errorMessage: router.errorMessage)
            case .editor(let vm):
                EditorView(vm: vm)
            }
        }
        // macOS convention: the title bar shows the current document; the app
        // name ("Légendes") lives in the menu bar. Show the file being tagged
        // while editing, and the app name on the launch screen.
        .navigationTitle(windowTitle)
    }

    private var windowTitle: String {
        switch router.screen {
        // No app name in the title bar before a video is open.
        case .dropZone: ""
        case .editor(let vm): vm.videoURL.deletingPathExtension().lastPathComponent
        }
    }
}
