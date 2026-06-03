import SwiftUI
import AppKit
import VideoTaggingCore

@main
struct VideoTaggingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup(Strings.appName) {
            RootView()
                .frame(minWidth: 900, minHeight: 700)
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
