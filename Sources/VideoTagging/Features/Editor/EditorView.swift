import SwiftUI
import AVKit
import VideoTaggingCore

struct EditorView: View {
    @Bindable var vm: EditorViewModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.m) {
                HStack {
                    Spacer()
                    BigButton(title: vm.isListVisible ? Strings.hideList : Strings.showList,
                              systemImage: "sidebar.right") { vm.isListVisible.toggle() }
                }

                VideoPlayer(player: vm.player)
                    .frame(minHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                TransportBar(
                    isPlaying: vm.isPlaying,
                    currentMs: vm.currentMs,
                    totalMs: vm.totalMs,
                    onTogglePlay: { vm.togglePlay() },
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

                HStack(spacing: Theme.Spacing.s) {
                    Button { vm.previousSection() } label: { Image(systemName: "chevron.left").font(.system(size: 24)) }
                        .buttonStyle(.plain)
                    TimelineView(
                        sections: vm.partition.sections,
                        totalMs: vm.totalMs,
                        currentIndex: vm.currentIndex,
                        onSelect: { vm.goToSection($0) },
                        onDragBoundary: { beforeIndex, toMs in
                            vm.partition.moveBoundary(beforeIndex: beforeIndex, toMs: toMs)
                            vm.save()
                        }
                    )
                    Button { vm.nextSection() } label: { Image(systemName: "chevron.right").font(.system(size: 24)) }
                        .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(Theme.Spacing.l)

            if vm.isListVisible {
                SectionListPanel(sections: vm.partition.sections,
                                 currentIndex: vm.currentIndex,
                                 onSelect: { vm.goToSection($0) })
            }
        }
        .background(Theme.Colors.background)
    }
}

struct SaveStatusLabel: View {
    let status: AutosaveService.Status
    var body: some View {
        let (text, color): (String, Color) = switch status {
            case .saved: (Strings.saved, Theme.Colors.textSecondary)
            case .saving: (Strings.saving, Theme.Colors.textSecondary)
            case .idle: ("", .clear)
            case .failed(let m): ("\(Strings.saveFailed): \(m)", Theme.Colors.error)
        }
        Text(text).font(Theme.Fonts.label).foregroundStyle(color)
    }
}
