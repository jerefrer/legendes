import SwiftUI
import VideoTaggingCore

struct EditorView: View {
    @Bindable var vm: EditorViewModel
    @State private var showHelp = false
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: theme.m) {
                TopBar(
                    canUndo: vm.canUndo, canRedo: vm.canRedo,
                    onUndo: { vm.undo() }, onRedo: { vm.redo() },
                    isListVisible: vm.isListVisible,
                    onToggleList: { withAnimation(.easeInOut(duration: 0.2)) { vm.isListVisible.toggle() } }
                )

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

                HStack(spacing: theme.s) {
                    Button { vm.previousSection() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)

                    TimelineView(
                        sections: vm.partition.sections,
                        totalMs: vm.totalMs,
                        currentIndex: vm.currentIndex,
                        onSelect: { vm.goToSection($0) },
                        onDragBoundary: { beforeIndex, toMs in vm.beginBoundaryDrag(beforeIndex: beforeIndex, toMs: toMs) },
                        onDragEnded: { vm.endBoundaryDrag() }
                    )

                    Button { vm.nextSection() } label: {
                        Image(systemName: "chevron.right").font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                }

                Spacer()
            }
            .padding(theme.l)

            if vm.isListVisible {
                SectionListPanel(sections: vm.partition.sections,
                                 currentIndex: vm.currentIndex,
                                 onSelect: { vm.goToSection($0) })
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(.background)
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
        .onKeyPress(keys: ["z"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            if press.modifiers.contains(.shift) { vm.redo() } else { vm.undo() }
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
    @Environment(\.theme) private var theme

    var body: some View {
        let (text, color): (String, Color) = switch status {
            case .saved: (Strings.saved, theme.textSecondary)
            case .saving: (Strings.saving, theme.textSecondary)
            case .idle: ("", .clear)
            case .failed(let m): ("\(Strings.saveFailed): \(m)", theme.error)
        }
        Text(text).font(theme.label).foregroundStyle(color)
    }
}
