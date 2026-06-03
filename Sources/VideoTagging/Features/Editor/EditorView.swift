import SwiftUI
import AVKit
import VideoTaggingCore

struct EditorView: View {
    @Bindable var vm: EditorViewModel
    @State private var isPlaying = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.m) {
                VideoPlayer(player: vm.player)
                    .frame(minHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                TransportBar(
                    isPlaying: isPlaying,
                    currentMs: vm.currentMs,
                    totalMs: vm.totalMs,
                    onTogglePlay: { vm.togglePlay(); isPlaying.toggle() },
                    onScrub: { vm.seek(toMs: $0) }
                )

                SectionCardView(
                    index: vm.currentIndex,
                    section: vm.currentSection,
                    canMoveStart: vm.currentIndex >= 1,
                    canMoveEnd: vm.currentIndex + 1 < vm.partition.sections.count,
                    canMerge: vm.currentIndex >= 1,
                    text: Binding(
                        get: { vm.currentSection.text },
                        set: { vm.updateCurrentText($0) }
                    ),
                    onCut: vm.cutHere,
                    onMoveStart: vm.moveStart(byMs:),
                    onMoveEnd: vm.moveEnd(byMs:),
                    onMerge: vm.mergeWithPrevious
                )

                SaveStatusLabel(status: vm.saveStatus)
                Spacer()
            }
            .padding(Theme.Spacing.l)
        }
        .background(Color(white: 0.1))
    }
}

struct SaveStatusLabel: View {
    let status: AutosaveService.Status
    var body: some View {
        let (text, color): (String, Color) = switch status {
            case .saved: (Strings.saved, Theme.Colors.textSecondary)
            case .saving: (Strings.saving, Theme.Colors.textSecondary)
            case .idle: ("", .clear)
            case .failed(let m): ("\(Strings.saveFailed): \(m)", .red)
        }
        Text(text).font(Theme.Fonts.label).foregroundStyle(color)
    }
}
