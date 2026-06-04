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

    var body: some Scene {
        WindowGroup(Strings.appName) {
            RootView()
                .frame(minWidth: 900, minHeight: 780)
                .environment(settings)
                .environment(\.theme, Theme(scale: settings.interfaceSize.scale))
                .onChange(of: settings.appearance, initial: true) { _, mode in
                    NSApp.appearance = mode.nsAppearance
                }
                .animation(.easeInOut(duration: 0.2), value: settings.interfaceSize)
        }
        .windowStyle(.titleBar)
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
        switch router.screen {
        case .dropZone:
            DropZoneView(onOpen: { router.open(urls: $0) }, errorMessage: router.errorMessage)
        case .editor(let vm):
            EditorView(vm: vm)
        }
    }
}
