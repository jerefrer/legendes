import SwiftUI
import VideoTaggingCore

struct EditorView: View {
    @Bindable var vm: EditorViewModel
    @State private var showHelp = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: Theme.Spacing.m) {
                HStack {
                    Spacer()
                    BigButton(title: vm.isListVisible ? Strings.hideList : Strings.showList,
                              systemImage: "sidebar.right") { vm.isListVisible.toggle() }
                }

                PlayerView(player: vm.player)
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
                    onMerge: vm.mergeWithPrevious,
                    onBeginEditing: { vm.beginTextEditing() },
                    onEndEditing: { vm.endTextEditing() }
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
                            vm.moveBoundaryByDrag(beforeIndex: beforeIndex, toMs: toMs)
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
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) { vm.togglePlay(); return .handled }
        .onKeyPress(keys: [.leftArrow]) { p in vm.jog(byMs: p.modifiers.contains(.shift) ? -1000 : -5000); return .handled }
        .onKeyPress(keys: [.rightArrow]) { p in vm.jog(byMs: p.modifiers.contains(.shift) ? 1000 : 5000); return .handled }
        .onKeyPress(keys: ["c", "\r"]) { _ in vm.cutHere(); return .handled }
        .onKeyPress(.upArrow) { vm.previousSection(); return .handled }
        .onKeyPress(.downArrow) { vm.nextSection(); return .handled }
        .onKeyPress(keys: [",", "."]) { press in
            let delta = press.key.character == "," ? -1000 : 1000
            if press.modifiers.contains(.shift) { vm.moveStart(byMs: delta) }
            else { vm.moveEnd(byMs: delta) }
            return .handled
        }
        .onAppear { PendingSaveFlusher.flush = { vm.flushSave() } }
        .onDisappear { vm.flushSave(); PendingSaveFlusher.flush = {} }
        .toolbar {
            ToolbarItem {
                Button { showHelp = true } label: { Image(systemName: "questionmark.circle") }
            }
        }
        .sheet(isPresented: $showHelp) { ShortcutsHelp { showHelp = false } }
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
