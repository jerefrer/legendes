import SwiftUI
import AppKit
import VideoTaggingCore

struct EditorView: View {
    @Bindable var vm: EditorViewModel
    @State private var showHelp = false
    @State private var videoHeight: CGFloat = 300
    @GestureState private var videoDrag: CGFloat = 0
    @State private var optionDown = false
    @State private var flagsMonitor: Any?
    @State private var cardMinHeight: CGFloat = 240   // measured min height of the section card
    @Environment(\.theme) private var theme
    @Environment(AppSettings.self) private var settings

    private let minVideoHeight: CGFloat = 160

    var body: some View {
        @Bindable var settings = settings
        HSplitView {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    // Cap the video so the transport + the full card always fit
                    // below it — buttons never slide under the timeline; only the
                    // description scrolls (internally). cardMinHeight is measured;
                    // the constant covers the video's top padding + handle +
                    // transport + the card's outer top padding.
                    let reserved = cardMinHeight + 140 * theme.scale
                    let maxVideo = max(minVideoHeight, geo.size.height - reserved)
                    let videoH = min(max(videoHeight + videoDrag, minVideoHeight), maxVideo)

                    VStack(spacing: 0) {
                        PlayerView(player: vm.player)
                            .frame(maxWidth: .infinity)
                            .frame(height: videoH)
                            .clipShape(RoundedRectangle(cornerRadius: theme.radiusSmall, style: .continuous))
                            .clipped()
                            .padding(.horizontal, theme.l)
                            .padding(.top, theme.l)

                        ResizeHandle()
                            .gesture(
                                // Global coordinate space: the handle moves as the
                                // video resizes, so a local-space translation would
                                // feed back and make the height oscillate.
                                DragGesture(coordinateSpace: .global)
                                    .updating($videoDrag) { value, state, _ in state = value.translation.height }
                                    .onEnded { value in
                                        videoHeight = min(max(videoHeight + value.translation.height, minVideoHeight), maxVideo)
                                    }
                            )

                        TransportBar(
                            isPlaying: vm.isPlaying,
                            currentMs: vm.currentMs,
                            totalMs: vm.totalMs,
                            onTogglePlay: { vm.togglePlay() },
                            onScrub: { vm.seek(toMs: $0) }
                        )
                        .padding(.horizontal, theme.l)
                        .padding(.top, theme.s)

                        // Card fills the remaining space; the description grows
                        // and scrolls internally — buttons stay put (no outer scroll).
                        SectionCardView(
                            index: vm.currentIndex,
                            section: vm.currentSection,
                            canMoveStart: vm.currentIndex >= 1,
                            canMoveEnd: vm.currentIndex + 1 < vm.partition.sections.count,
                            canMergePrevious: vm.currentIndex >= 1,
                            canMergeNext: vm.currentIndex + 1 < vm.partition.sections.count,
                            canCut: vm.canCut,
                            optionDown: optionDown,
                            text: Binding(
                                get: { vm.currentSection.text },
                                set: { vm.updateCurrentText($0) }
                            ),
                            onCut: vm.cutHere,
                            onMoveStart: vm.moveStart(byMs:),
                            onMoveEnd: vm.moveEnd(byMs:),
                            onMergePrevious: vm.mergeWithPrevious,
                            onMergeNext: vm.mergeWithNext,
                            onBeginEditing: { vm.beginTextEditing() },
                            onEndEditing: { vm.endTextEditing() }
                        )
                        .frame(maxHeight: .infinity)
                        .padding([.horizontal, .top], theme.l)
                    }
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
                .padding(.top, theme.m)
                // Same breathing room below the timeline as above the video.
                .padding(.bottom, theme.l)
            }
            .frame(minWidth: 460)

            if vm.isListVisible {
                SectionListPanel(sections: vm.partition.sections,
                                 currentIndex: vm.currentIndex,
                                 onSelect: { vm.goToSection($0) })
                    .frame(minWidth: 240, idealWidth: 320 * theme.scale, maxWidth: 560)
            }
        }
        .background(.background)
        .onPreferenceChange(CardMinHeightKey.self) { cardMinHeight = $0 }
        .focusable()
        .focusEffectDisabled()
        // While editing the description, let every key reach the text field
        // (Space must type a space, arrows move the caret, etc.).
        .onKeyPress(.space) { vm.isEditingText ? .ignored : { vm.togglePlay(); return .handled }() }
        .onKeyPress(keys: [.leftArrow]) { p in
            guard !vm.isEditingText else { return .ignored }
            vm.jog(byMs: p.modifiers.contains(.shift) ? -1000 : -5000); return .handled
        }
        .onKeyPress(keys: [.rightArrow]) { p in
            guard !vm.isEditingText else { return .ignored }
            vm.jog(byMs: p.modifiers.contains(.shift) ? 1000 : 5000); return .handled
        }
        .onKeyPress(keys: ["c", "\r"]) { _ in
            guard !vm.isEditingText else { return .ignored }
            vm.cutHere(); return .handled
        }
        .onKeyPress(.upArrow) { vm.isEditingText ? .ignored : { vm.previousSection(); return .handled }() }
        .onKeyPress(.downArrow) { vm.isEditingText ? .ignored : { vm.nextSection(); return .handled }() }
        .onKeyPress(keys: [",", "."]) { press in
            guard !vm.isEditingText else { return .ignored }
            let delta = press.key.character == "," ? -1000 : 1000
            if press.modifiers.contains(.shift) { vm.moveStart(byMs: delta) }
            else { vm.moveEnd(byMs: delta) }
            return .handled
        }
        .onKeyPress(keys: ["z"]) { press in
            // Let the text field's native undo work while editing.
            guard !vm.isEditingText, press.modifiers.contains(.command) else { return .ignored }
            if press.modifiers.contains(.shift) { vm.redo() } else { vm.undo() }
            return .handled
        }
        .onAppear {
            PendingSaveFlusher.flush = { vm.flushSave() }
            flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                optionDown = event.modifierFlags.contains(.option)
                return event
            }
        }
        .onDisappear {
            vm.flushSave(); PendingSaveFlusher.flush = {}
            if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
            flagsMonitor = nil
        }
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
            // Centered status. macOS 26 wraps toolbar items in a glass capsule
            // (not removable via the API), so keep it tidy with inner padding.
            ToolbarItem(placement: .status) {
                SaveStatusBadge(status: vm.saveStatus)
            }
            ToolbarItemGroup(placement: .primaryAction) {
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

/// Draggable handle between the video and the editing area.
private struct ResizeHandle: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Color.clear.frame(height: 14).contentShape(Rectangle())
            Capsule().fill(theme.textSecondary.opacity(0.4)).frame(width: 44, height: 4)
        }
        .frame(maxWidth: .infinity)
        .onHover { inside in
            if inside { NSCursor.resizeUpDown.set() } else { NSCursor.arrow.set() }
        }
    }
}

/// Save status shown in the toolbar. Non-interactive (`allowsHitTesting(false)`)
/// so macOS doesn't draw a button-like hover/focus background around it.
private struct SaveStatusBadge: View {
    let status: AutosaveService.Status
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            switch status {
            case .saved:
                HStack(spacing: theme.xs) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(Strings.saved).foregroundStyle(theme.textSecondary)
                }
            case .saving:
                HStack(spacing: theme.xs) {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(theme.textSecondary)
                    Text(Strings.saving).foregroundStyle(theme.textSecondary)
                }
            case .failed:
                HStack(spacing: theme.xs) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(theme.error)
                    Text(Strings.saveFailed).foregroundStyle(theme.error)
                }
            case .idle:
                EmptyView()
            }
        }
        .padding(.horizontal, theme.s)
        .allowsHitTesting(false)
    }
}
