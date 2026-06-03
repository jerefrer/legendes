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

// Temporary root for Phase 2 launch verification; replaced by AppRouter in Phase 3.
struct RootView: View {
    @State private var vm: EditorViewModel?

    var body: some View {
        Group {
            if let vm { EditorView(vm: vm) }
            else { Text("Set VIDEO_TAGGER_SAMPLE to a video path to test.").padding() }
        }
        .task { await load() }
    }

    @MainActor private func load() async {
        guard vm == nil,
              let path = ProcessInfo.processInfo.environment["VIDEO_TAGGER_SAMPLE"] else { return }
        let video = URL(fileURLWithPath: path)
        let srt = video.deletingPathExtension().appendingPathExtension("srt")
        let durationMs = await videoDurationMs(video)
        let partition: SectionPartition
        if let content = try? String(contentsOf: srt, encoding: .utf8) {
            partition = SectionPartition(duration: durationMs, fromEntries: SRTParser.parse(content))
        } else {
            partition = SectionPartition(duration: durationMs)
        }
        vm = EditorViewModel(videoURL: video, srtURL: srt, partition: partition)
    }
}
