import SwiftUI
import VideoTaggingCore

struct EditorView: View {
    @Bindable var vm: EditorViewModel
    @State private var showHelp = false
    @Environment(\.theme) private var theme
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                // Scrollable middle: video + transport + section card stay reachable
                // at any interface size.
                ScrollView {
                    VStack(spacing: theme.m) {
                        PlayerView(player: vm.player)
                            .frame(minHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSmall, style: .continuous))

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
                    }
                    .padding(theme.l)
                }

                // Pinned timeline: always reachable, never scrolled away.
                HStack(spacing: theme.s) {
                    Button { vm.previousSection() } label: {
                        Image(systemName: "chevron.left").font(.system(size: 22 * theme.scale))
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
                        Image(systemName: "chevron.right").font(.system(size: 22 * theme.scale))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.textSecondary)
                }
                .padding(.horizontal, theme.l)
                .padding(.vertical, theme.s)
                .background(.bar)
            }

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
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { vm.undo() }) {
                    Label(Strings.undo, systemImage: "arrow.uturn.backward")
                }
                .disabled(!vm.canUndo)
                Button(action: { vm.redo() }) {
                    Label(Strings.redo, systemImage: "arrow.uturn.forward")
                }
                .disabled(!vm.canRedo)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Interface size", selection: $settings.interfaceSize) {
                    Text("A").font(.system(size: 11)).tag(InterfaceSize.comfortable)
                    Text("A").font(.system(size: 14)).tag(InterfaceSize.large)
                    Text("A").font(.system(size: 17)).tag(InterfaceSize.extraLarge)
                }
                .pickerStyle(.segmented)
                .help("Interface size")

                Picker("Appearance", selection: $settings.appearance) {
                    Image(systemName: "circle.lefthalf.filled").tag(AppearanceMode.system)
                    Image(systemName: "sun.max").tag(AppearanceMode.light)
                    Image(systemName: "moon").tag(AppearanceMode.dark)
                }
                .pickerStyle(.segmented)
                .help("Appearance")

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { vm.isListVisible.toggle() }
                } label: {
                    Label(vm.isListVisible ? Strings.hideList : Strings.showList, systemImage: "sidebar.right")
                }

                Button { showHelp = true } label: { Image(systemName: "questionmark.circle") }
                    .help(Strings.keyboardShortcutsTitle)
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
