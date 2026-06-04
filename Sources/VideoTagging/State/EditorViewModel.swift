import Foundation
import AVKit
import Observation
import VideoTaggingCore

@MainActor
@Observable
final class EditorViewModel {
    let videoURL: URL
    let srtURL: URL
    let player: AVPlayer

    var partition: SectionPartition
    var currentIndex: Int = 0
    var currentMs: Int = 0
    var totalMs: Int = 0
    var isListVisible: Bool = false
    var saveStatus: AutosaveService.Status = .saved
    var isPlaying: Bool = false
    var isEditingText: Bool = false

    private var undoStack = UndoStack<EditorSnapshot>()
    var canUndo: Bool { undoStack.canUndo }
    var canRedo: Bool { undoStack.canRedo }
    private var isDraggingBoundary = false

    private var snapshot: EditorSnapshot {
        EditorSnapshot(sections: partition.sections, currentIndex: currentIndex)
    }

    /// Record the pre-edit state. Call BEFORE mutating for discrete edits.
    private func recordUndo() { undoStack.record(snapshot) }

    private func apply(_ snap: EditorSnapshot) {
        partition.replaceSections(snap.sections)
        currentIndex = min(max(snap.currentIndex, 0), partition.sections.count - 1)
        seek(toMs: partition.sections[currentIndex].start)
    }

    func undo() {
        if let restored = undoStack.undo(current: snapshot) { apply(restored); save() }
    }
    func redo() {
        if let restored = undoStack.redo(current: snapshot) { apply(restored); save() }
    }

    private let autosave = AutosaveService()
    // @ObservationIgnored + nonisolated(unsafe): deinit is nonisolated in Swift 6;
    // this var is only ever written/read on the main thread.
    @ObservationIgnored nonisolated(unsafe) private var timeObserver: Any?
    @ObservationIgnored nonisolated(unsafe) private var statusObservation: NSKeyValueObservation?

    init(videoURL: URL, srtURL: URL, partition: SectionPartition) {
        self.videoURL = videoURL
        self.srtURL = srtURL
        self.partition = partition
        self.totalMs = partition.duration
        self.player = AVPlayer(url: videoURL)
        observePlayhead()
        statusObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in
                self?.isPlaying = (player.timeControlStatus == .playing)
            }
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        statusObservation = nil
    }

    private func observePlayhead() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            // The callback runs on .main; hop to MainActor to satisfy Swift 6 isolation.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentMs = Int(time.seconds * 1000)
                // Only track section index when the user is not editing text,
                // so keystrokes always target the section they started editing.
                if !self.isEditingText {
                    self.currentIndex = self.partition.indexContaining(ms: self.currentMs)
                }
            }
        }
    }

    // M1: clamp the index so an out-of-range value never crashes.
    var currentSection: Section {
        let i = min(max(currentIndex, 0), partition.sections.count - 1)
        return partition.sections[i]
    }

    // MARK: Playback
    func togglePlay() {
        player.timeControlStatus == .playing ? player.pause() : player.play()
    }
    func seek(toMs ms: Int) {
        let clamped = min(max(ms, 0), totalMs)
        player.seek(to: CMTime(value: CMTimeValue(clamped), timescale: 1000),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        currentMs = clamped
        // M2: keep currentIndex coherent immediately after a seek.
        currentIndex = partition.indexContaining(ms: clamped)
    }
    func jog(byMs delta: Int) { seek(toMs: currentMs + delta) }

    // MARK: Navigation
    func goToSection(_ index: Int) {
        guard partition.sections.indices.contains(index) else { return }
        currentIndex = index
        seek(toMs: partition.sections[index].start)
    }
    func previousSection() { goToSection(currentIndex - 1) }
    func nextSection() { goToSection(currentIndex + 1) }

    // MARK: Text editing focus
    // Text editing: record ONE undo step at focus-in, before any keystroke.
    func beginTextEditing() {
        recordUndo()
        player.pause()
        isEditingText = true
    }
    func endTextEditing() { isEditingText = false }

    // MARK: Editing (delegates to Core, then saves)
    func cutHere() {
        recordUndo()
        partition.cut(atMs: currentMs)
        currentIndex = partition.indexContaining(ms: currentMs)
        save()
    }
    func moveStart(byMs delta: Int) {
        guard currentIndex >= 1 else { return }
        recordUndo()
        partition.moveBoundary(beforeIndex: currentIndex,
                               toMs: partition.sections[currentIndex].start + delta)
        save()
    }
    func moveEnd(byMs delta: Int) {
        let boundary = currentIndex + 1
        guard boundary < partition.sections.count else { return }
        recordUndo()
        partition.moveBoundary(beforeIndex: boundary,
                               toMs: partition.sections[currentIndex].end + delta)
        save()
    }
    func mergeWithPrevious() {
        guard currentIndex >= 1 else { return }
        recordUndo()
        partition.merge(boundaryBeforeIndex: currentIndex)
        currentIndex = max(0, currentIndex - 1)
        save()
    }
    func updateCurrentText(_ text: String) {
        partition.sections[currentIndex].text = text
        save()
    }

    // Boundary drag: record once at the start of the gesture.
    func beginBoundaryDrag(beforeIndex: Int, toMs: Int) {
        if !isDraggingBoundary { recordUndo(); isDraggingBoundary = true }
        partition.moveBoundary(beforeIndex: beforeIndex, toMs: toMs)
    }
    func endBoundaryDrag() { isDraggingBoundary = false; save() }

    func save() {
        autosave.scheduleSave(sections: partition.sections, to: srtURL) { [weak self] status in
            self?.saveStatus = status
        }
    }

    // C1: flush any pending debounced save synchronously (used on termination).
    func flushSave() { autosave.flushNow() }
}

import AVFoundation

func videoDurationMs(_ url: URL) async -> Int {
    let asset = AVURLAsset(url: url)
    let duration = (try? await asset.load(.duration)) ?? .zero
    return max(1, Int(duration.seconds * 1000))
}
