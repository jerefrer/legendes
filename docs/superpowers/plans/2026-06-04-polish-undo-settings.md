# Polish, Undo/Redo & Display Settings — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add full Undo/Redo (with buttons), an interface-size + appearance setting, and a refined native-macOS visual redesign to the shipped Video Section Tagger.

**Architecture:** Pure logic (enums for size/appearance, a generic `UndoStack`, the `EditorSnapshot`) lives in `VideoTaggingCore` (TDD). The app gains an `@Observable AppSettings` (UserDefaults-backed), a scale-aware/appearance-adaptive `Theme` provided through the SwiftUI environment, undo wiring in `EditorViewModel`, and a restyled view layer using native materials, SF Pro hierarchy, depth, and motion.

**Tech Stack:** Swift 6.2, SwiftUI + AVFoundation, Swift Package Manager, Swift Testing.

---

## File Structure

```
Sources/VideoTaggingCore/
  Settings/InterfaceSize.swift     (NEW) scale presets
  Settings/AppearanceMode.swift    (NEW) system/light/dark raw enum
  Undo/UndoStack.swift             (NEW) generic bounded undo/redo stack
  Undo/EditorSnapshot.swift        (NEW) {sections, currentIndex}
Sources/VideoTagging/
  State/AppSettings.swift          (NEW) @Observable, UserDefaults-backed
  Theme/Theme.swift                (REWRITE) struct, env-provided, scaled, adaptive
  Theme/AppearanceMode+UI.swift    (NEW) ColorScheme mapping (app side)
  State/EditorViewModel.swift      (MODIFY) undo stack + record/undo/redo
  Components/BigButton.swift        (REWRITE) themed, polished, scaled
  Components/TimeLabel.swift        (REWRITE) themed
  Components/TopBar.swift           (NEW) undo/redo + size/appearance controls
  Features/Editor/EditorView.swift  (MODIFY) top bar, env theme, shortcuts, motion
  Features/Editor/TransportBar.swift(REWRITE) themed/polished
  Features/Editor/SectionCardView.swift (REWRITE) themed/polished
  Features/Editor/TimelineView.swift (REWRITE) themed/polished + motion
  Features/Editor/ShortcutsHelp.swift (REWRITE) themed
  Features/SectionList/SectionListPanel.swift (REWRITE) themed/polished
  Features/DropZone/DropZoneView.swift (MODIFY) themed/polished
  VideoTaggingApp.swift            (MODIFY) inject AppSettings + theme + colorScheme
Tests/VideoTaggingCoreTests/
  InterfaceSizeTests.swift, AppearanceModeTests.swift, UndoStackTests.swift
```

---

# PHASE 1 — Settings & Undo foundation (logic, no visual change)

### Task 1: InterfaceSize + AppearanceMode (Core, TDD)

**Files:**
- Create: `Sources/VideoTaggingCore/Settings/InterfaceSize.swift`
- Create: `Sources/VideoTaggingCore/Settings/AppearanceMode.swift`
- Test: `Tests/VideoTaggingCoreTests/InterfaceSizeTests.swift`, `Tests/VideoTaggingCoreTests/AppearanceModeTests.swift`

- [ ] **Step 1: Write failing tests**

`Tests/VideoTaggingCoreTests/InterfaceSizeTests.swift`:
```swift
import Testing
@testable import VideoTaggingCore

@Suite struct InterfaceSizeTests {
    @Test func scaleValues() {
        #expect(InterfaceSize.comfortable.scale == 1.0)
        #expect(InterfaceSize.large.scale == 1.2)
        #expect(InterfaceSize.extraLarge.scale == 1.45)
    }
    @Test func roundTripsRawValue() {
        for size in InterfaceSize.allCases {
            #expect(InterfaceSize(rawValue: size.rawValue) == size)
        }
    }
    @Test func defaultIsComfortable() {
        #expect(InterfaceSize.defaultValue == .comfortable)
    }
    @Test func fallbackForUnknownRaw() {
        #expect(InterfaceSize(storedValue: "bogus") == .comfortable)
        #expect(InterfaceSize(storedValue: "large") == .large)
    }
}
```

`Tests/VideoTaggingCoreTests/AppearanceModeTests.swift`:
```swift
import Testing
@testable import VideoTaggingCore

@Suite struct AppearanceModeTests {
    @Test func roundTripsRawValue() {
        for mode in AppearanceMode.allCases {
            #expect(AppearanceMode(rawValue: mode.rawValue) == mode)
        }
    }
    @Test func defaultIsSystem() {
        #expect(AppearanceMode.defaultValue == .system)
    }
    @Test func fallbackForUnknownRaw() {
        #expect(AppearanceMode(storedValue: "bogus") == .system)
        #expect(AppearanceMode(storedValue: "dark") == .dark)
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter InterfaceSizeTests` then `swift test --filter AppearanceModeTests`
Expected: FAIL (types missing).

- [ ] **Step 3: Implement**

`Sources/VideoTaggingCore/Settings/InterfaceSize.swift`:
```swift
import CoreGraphics

public enum InterfaceSize: String, CaseIterable, Sendable {
    case comfortable
    case large
    case extraLarge

    public static let defaultValue: InterfaceSize = .comfortable

    /// Multiplier applied to fonts, control sizes, and spacing.
    public var scale: CGFloat {
        switch self {
        case .comfortable: 1.0
        case .large: 1.2
        case .extraLarge: 1.45
        }
    }

    /// Total over a persisted string, falling back to the default.
    public init(storedValue: String?) {
        self = storedValue.flatMap(InterfaceSize.init(rawValue:)) ?? .defaultValue
    }
}
```

`Sources/VideoTaggingCore/Settings/AppearanceMode.swift`:
```swift
public enum AppearanceMode: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    public static let defaultValue: AppearanceMode = .system

    public init(storedValue: String?) {
        self = storedValue.flatMap(AppearanceMode.init(rawValue:)) ?? .defaultValue
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter InterfaceSizeTests` and `swift test --filter AppearanceModeTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoTaggingCore/Settings Tests/VideoTaggingCoreTests/InterfaceSizeTests.swift Tests/VideoTaggingCoreTests/AppearanceModeTests.swift
git commit -m "feat(core): interface size and appearance settings enums"
```

---

### Task 2: UndoStack + EditorSnapshot (Core, TDD)

**Files:**
- Create: `Sources/VideoTaggingCore/Undo/EditorSnapshot.swift`
- Create: `Sources/VideoTaggingCore/Undo/UndoStack.swift`
- Test: `Tests/VideoTaggingCoreTests/UndoStackTests.swift`

Model: the live state lives outside the stack. `record(_:)` pushes the *pre-edit*
state onto the past and clears the redo future. `undo(current:)` returns the
state to restore and remembers `current` for redo. `redo(current:)` is symmetric.

- [ ] **Step 1: Write failing tests**

```swift
import Testing
@testable import VideoTaggingCore

@Suite struct UndoStackTests {
    @Test func startsEmpty() {
        let s = UndoStack<Int>(maxDepth: 10)
        #expect(!s.canUndo)
        #expect(!s.canRedo)
    }

    @Test func recordEnablesUndo() {
        var s = UndoStack<Int>(maxDepth: 10)
        s.record(1)            // pre-edit state was 1
        #expect(s.canUndo)
        #expect(!s.canRedo)
    }

    @Test func undoReturnsPreviousAndEnablesRedo() {
        var s = UndoStack<Int>(maxDepth: 10)
        s.record(1)            // state was 1, then live became 2
        let restored = s.undo(current: 2)
        #expect(restored == 1)
        #expect(!s.canUndo)
        #expect(s.canRedo)
    }

    @Test func redoReturnsForwardState() {
        var s = UndoStack<Int>(maxDepth: 10)
        s.record(1)
        _ = s.undo(current: 2)     // back to 1
        let redone = s.redo(current: 1)
        #expect(redone == 2)
        #expect(s.canUndo)
        #expect(!s.canRedo)
    }

    @Test func recordClearsRedoFuture() {
        var s = UndoStack<Int>(maxDepth: 10)
        s.record(1)
        _ = s.undo(current: 2)     // canRedo == true
        s.record(1)                // a new edit clears redo
        #expect(!s.canRedo)
    }

    @Test func undoOnEmptyReturnsNil() {
        var s = UndoStack<Int>(maxDepth: 10)
        #expect(s.undo(current: 5) == nil)
    }

    @Test func boundedDepthEvictsOldest() {
        var s = UndoStack<Int>(maxDepth: 2)
        s.record(1); s.record(2); s.record(3)   // only 2 and 3 retained
        #expect(s.undo(current: 99) == 3)
        #expect(s.undo(current: 3) == 2)
        #expect(!s.canUndo)                      // 1 was evicted
    }
}
```

- [ ] **Step 2: Run to verify failure**

Run: `swift test --filter UndoStackTests`
Expected: FAIL.

- [ ] **Step 3: Implement**

`Sources/VideoTaggingCore/Undo/EditorSnapshot.swift`:
```swift
public struct EditorSnapshot: Equatable, Sendable {
    public var sections: [Section]
    public var currentIndex: Int
    public init(sections: [Section], currentIndex: Int) {
        self.sections = sections
        self.currentIndex = currentIndex
    }
}
```

`Sources/VideoTaggingCore/Undo/UndoStack.swift`:
```swift
public struct UndoStack<State>: Sendable where State: Sendable {
    private var past: [State] = []
    private var future: [State] = []
    private let maxDepth: Int

    public init(maxDepth: Int = 100) {
        self.maxDepth = max(1, maxDepth)
    }

    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }

    /// Record the state that existed BEFORE an edit. Clears the redo future.
    public mutating func record(_ preEditState: State) {
        past.append(preEditState)
        if past.count > maxDepth { past.removeFirst(past.count - maxDepth) }
        future.removeAll()
    }

    /// Restore the previous state. `current` is the live state, kept for redo.
    public mutating func undo(current: State) -> State? {
        guard let previous = past.popLast() else { return nil }
        future.append(current)
        return previous
    }

    /// Re-apply a previously undone state. `current` is kept for undo.
    public mutating func redo(current: State) -> State? {
        guard let next = future.popLast() else { return nil }
        past.append(current)
        return next
    }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `swift test --filter UndoStackTests`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoTaggingCore/Undo Tests/VideoTaggingCoreTests/UndoStackTests.swift
git commit -m "feat(core): generic bounded UndoStack and EditorSnapshot"
```

---

### Task 3: AppSettings + root wiring (appearance works immediately)

**Files:**
- Create: `Sources/VideoTagging/State/AppSettings.swift`
- Create: `Sources/VideoTagging/Theme/AppearanceMode+UI.swift`
- Modify: `Sources/VideoTagging/VideoTaggingApp.swift`

- [ ] **Step 1: AppSettings (UserDefaults-backed, observable)**

`Sources/VideoTagging/State/AppSettings.swift`:
```swift
import Foundation
import Observation
import VideoTaggingCore

@MainActor
@Observable
final class AppSettings {
    var interfaceSize: InterfaceSize {
        didSet { defaults.set(interfaceSize.rawValue, forKey: Keys.size) }
    }
    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private let defaults: UserDefaults
    private enum Keys {
        static let size = "interfaceSize"
        static let appearance = "appearanceMode"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.interfaceSize = InterfaceSize(storedValue: defaults.string(forKey: Keys.size))
        self.appearance = AppearanceMode(storedValue: defaults.string(forKey: Keys.appearance))
    }
}
```

- [ ] **Step 2: AppearanceMode → ColorScheme mapping (app side)**

`Sources/VideoTagging/Theme/AppearanceMode+UI.swift`:
```swift
import SwiftUI
import VideoTaggingCore

extension AppearanceMode {
    /// nil means "follow the system".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
```

- [ ] **Step 3: Inject settings + appearance at the app root**

In `VideoTaggingApp.swift`, add a settings instance and apply appearance. Change the `VideoTaggingApp` struct and `RootView`:
```swift
@main
struct VideoTaggingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup(Strings.appName) {
            RootView()
                .frame(minWidth: 900, minHeight: 700)
                .environment(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
        }
        .windowStyle(.titleBar)
    }
}
```
(Leave `AppDelegate`, `PendingSaveFlusher`, and `RootView`'s switch body unchanged for now.)

- [ ] **Step 4: Build**

Run: `swift build`
Expected: `Build complete!` (no visual change yet except that appearance defaults to System; setting it later will switch light/dark).

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoTagging/State/AppSettings.swift Sources/VideoTagging/Theme/AppearanceMode+UI.swift Sources/VideoTagging/VideoTaggingApp.swift
git commit -m "feat(app): AppSettings (size + appearance) injected at root"
```

---

### Task 4: Undo/Redo in EditorViewModel + shortcuts + temporary buttons

**Files:**
- Modify: `Sources/VideoTagging/State/EditorViewModel.swift`
- Modify: `Sources/VideoTagging/Features/Editor/EditorView.swift`

- [ ] **Step 1: Add the undo stack and operations to the view model**

In `EditorViewModel.swift`, add near the other stored properties (after `var isEditingText`):
```swift
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
```

Update the discrete edit methods to record first. Replace the existing
`cutHere`, `moveStart`, `moveEnd`, `mergeWithPrevious`, `beginTextEditing`,
`moveBoundaryByDrag`, and add drag grouping:
```swift
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

    // Text editing: record ONE undo step at focus-in, before any keystroke.
    func beginTextEditing() {
        recordUndo()
        player.pause()
        isEditingText = true
    }
    func endTextEditing() { isEditingText = false }

    // Boundary drag: record once at the start of the gesture.
    func beginBoundaryDrag(beforeIndex: Int, toMs: Int) {
        if !isDraggingBoundary { recordUndo(); isDraggingBoundary = true }
        partition.moveBoundary(beforeIndex: beforeIndex, toMs: toMs)
    }
    func endBoundaryDrag() { isDraggingBoundary = false; save() }
```
Delete the old `moveBoundaryByDrag(beforeIndex:toMs:)` method (replaced by
`beginBoundaryDrag`/`endBoundaryDrag`). Keep `updateCurrentText` unchanged (no
`recordUndo` — the snapshot was taken at `beginTextEditing`).

- [ ] **Step 2: Add `replaceSections` to SectionPartition (Core)**

`apply` needs to set sections wholesale while preserving the duration invariant.
In `Sources/VideoTaggingCore/Partition/SectionPartition.swift`, add:
```swift
    /// Replace all sections (used by undo/redo to restore a snapshot).
    /// Assumes the snapshot was produced by this partition, so it already
    /// satisfies the contiguity/duration invariant.
    public mutating func replaceSections(_ newSections: [Section]) {
        guard !newSections.isEmpty else { return }
        sections = newSections
    }
```
Add a Core test in `Tests/VideoTaggingCoreTests/SectionPartitionTests.swift`:
```swift
    @Test func replaceSectionsRestoresState() {
        var p = SectionPartition(duration: 60_000)
        p.cut(atMs: 30_000)
        let snapshot = p.sections
        p.merge(boundaryBeforeIndex: 1)
        #expect(p.sections.count == 1)
        p.replaceSections(snapshot)
        #expect(p.sections.count == 2)
    }
```
Run: `swift test --filter SectionPartitionTests` → expect PASS.

- [ ] **Step 3: Wire ⌘Z / ⇧⌘Z and add temporary Undo/Redo buttons**

In `EditorView.swift`, add keyboard shortcuts. After the existing
`.onKeyPress(keys: [",", "."])` block, add:
```swift
        .onKeyPress(keys: ["z"]) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            if press.modifiers.contains(.shift) { vm.redo() } else { vm.undo() }
            return .handled
        }
```
And add a temporary Undo/Redo control to the existing top `HStack` (the one with
the Show/Hide list button). Replace that `HStack` with:
```swift
                HStack {
                    BigButton(title: "Undo", systemImage: "arrow.uturn.backward") { vm.undo() }
                        .disabled(!vm.canUndo)
                    BigButton(title: "Redo", systemImage: "arrow.uturn.forward") { vm.redo() }
                        .disabled(!vm.canRedo)
                    Spacer()
                    BigButton(title: vm.isListVisible ? Strings.hideList : Strings.showList,
                              systemImage: "sidebar.right") { vm.isListVisible.toggle() }
                }
```
Also update the timeline `onDragBoundary` usage: change the `TimelineView`'s
`onDragBoundary` closure to use the new methods. Replace the timeline block's
`onDragBoundary:` argument and add an `onDragEnded:` (TimelineView gets this new
parameter in Phase 2; for now, since TimelineView still has only `onDragBoundary`,
keep the call compiling by routing through begin/end within the single closure is
not possible). **To keep Phase 1 compiling without changing TimelineView yet**,
temporarily implement the drag boundary via begin/end by having the closure call
`vm.beginBoundaryDrag` on change; the end will be wired when TimelineView is
rewritten in Phase 2. For now set:
```swift
                        onDragBoundary: { beforeIndex, toMs in
                            vm.beginBoundaryDrag(beforeIndex: beforeIndex, toMs: toMs)
                        }
```
and add a `.onChange(of: vm.currentIndex)`-independent safety: call
`vm.endBoundaryDrag()` is deferred to Phase 2's TimelineView rewrite. (Acceptable
intermediate: the drag still works and records one undo group that is finalized
on the next save.) Note this limitation in your commit message.

Add `Strings.undo`/`Strings.redo` constants in `Strings.swift`:
```swift
    static let undo = "Undo"
    static let redo = "Redo"
```
and use `Strings.undo` / `Strings.redo` instead of the literals above.

- [ ] **Step 4: Build + test**

Run: `swift build` then `swift test`
Expected: build clean; all tests pass (now includes the new core tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/VideoTagging Sources/VideoTaggingCore/Partition/SectionPartition.swift Tests/VideoTaggingCoreTests/SectionPartitionTests.swift
git commit -m "feat(app): undo/redo in editor view model + cmd-Z + temporary buttons"
```

---

# PHASE 2 — Visual redesign (themed, scaled, polished)

> Phase 2 replaces the static `Theme` with an environment-provided, scale-aware,
> appearance-adaptive `Theme`, then restyles each view to a refined native-macOS
> look using materials, depth, SF Pro hierarchy, and motion. Every view migrates
> from `Theme.Colors.X` / `Theme.Fonts.X` / `Theme.Spacing.X` to
> `@Environment(\.theme) private var theme` + `theme.X`. Build after each task.

### Task 5: Theme as an environment-provided, scaled, adaptive value

**Files:**
- Rewrite: `Sources/VideoTagging/Theme/Theme.swift`
- Modify: `Sources/VideoTagging/VideoTaggingApp.swift`

- [ ] **Step 1: Rewrite Theme**

`Sources/VideoTagging/Theme/Theme.swift` (full replacement):
```swift
import SwiftUI

/// Design system resolved from the current interface scale. Colors are semantic
/// so they adapt to light/dark automatically; panels use native materials.
struct Theme: Sendable {
    let scale: CGFloat

    // Spacing (4/8pt grid, scaled)
    var xs: CGFloat { 4 * scale }
    var s: CGFloat { 8 * scale }
    var m: CGFloat { 16 * scale }
    var l: CGFloat { 24 * scale }
    var xl: CGFloat { 36 * scale }

    // Corner radii (continuous style applied at call sites)
    var radius: CGFloat { 14 * scale }
    var radiusSmall: CGFloat { 10 * scale }
    var controlHeight: CGFloat { 52 * scale }

    // Typography (SF Pro)
    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size * scale, weight: weight)
    }
    var title: Font { font(24, .semibold) }
    var body: Font { font(20) }
    var button: Font { font(18, .semibold) }
    var time: Font { .system(size: 26 * scale, weight: .semibold, design: .rounded).monospacedDigit() }
    var label: Font { font(12, .semibold) }
    var listItem: Font { font(16) }

    // Semantic colors (auto light/dark)
    var accent: Color { .accentColor }
    var textPrimary: Color { .primary }
    var textSecondary: Color { .secondary }
    var textOnAccent: Color { .white }
    var error: Color { .red }
    var separator: Color { .primary.opacity(0.08) }
    /// Tint for "gap"/empty sections on the timeline & list.
    var gap: Color { .orange }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme(scale: 1.0)
}
extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
```

- [ ] **Step 2: Inject the scaled theme at root**

In `VideoTaggingApp.swift`, add the theme to the environment, driven by the size
setting. Update the `WindowGroup` content:
```swift
            RootView()
                .frame(minWidth: 900, minHeight: 700)
                .environment(settings)
                .environment(\.theme, Theme(scale: settings.interfaceSize.scale))
                .preferredColorScheme(settings.appearance.colorScheme)
                .animation(.easeInOut(duration: 0.2), value: settings.interfaceSize)
```

- [ ] **Step 3: Build — this WILL fail to compile until Tasks 6–10 migrate the views**

This task intentionally breaks the build (views still reference the old static
`Theme.Colors`/`Fonts`/`Spacing`). Do NOT try to fix the views here. Proceed
immediately to Task 6; the build is expected to be red until Task 10. **Do not
commit yet** — commit at the end of Task 6 once `BigButton`/`TimeLabel`/`TopBar`
compile, then per task. (If you prefer a green tree per task, you may migrate all
views in one large commit, but the per-view tasks below are the intended path.)

---

### Task 6: Restyle shared components + new TopBar

**Files:**
- Rewrite: `Sources/VideoTagging/Components/BigButton.swift`
- Rewrite: `Sources/VideoTagging/Components/TimeLabel.swift`
- Create: `Sources/VideoTagging/Components/TopBar.swift`

- [ ] **Step 1: BigButton (themed, scaled, polished, hover/press states)**

`Sources/VideoTagging/Components/BigButton.swift` (full replacement):
```swift
import SwiftUI

struct BigButton: View {
    let title: String
    var prominent: Bool = false
    var systemImage: String? = nil
    let action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(theme.button)
            .padding(.vertical, theme.s + 6)
            .padding(.horizontal, theme.m)
            .frame(maxWidth: prominent ? .infinity : nil, minHeight: theme.controlHeight)
            .foregroundStyle(prominent ? theme.textOnAccent : theme.textPrimary)
            .background {
                RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                    .fill(prominent ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.regularMaterial))
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                    .strokeBorder(theme.separator, lineWidth: prominent ? 0 : 1)
            }
            .shadow(color: .black.opacity(prominent && isEnabled ? 0.18 : 0), radius: 8, y: 3)
            .brightness(hovering && isEnabled ? 0.05 : 0)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
```

- [ ] **Step 2: TimeLabel (themed)**

`Sources/VideoTagging/Components/TimeLabel.swift` (full replacement):
```swift
import SwiftUI
import VideoTaggingCore

struct TimeLabel: View {
    let currentMs: Int
    let totalMs: Int
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.xs) {
            Text(SRTTime(milliseconds: currentMs).displayString)
                .foregroundStyle(theme.textPrimary)
            Text("/").foregroundStyle(theme.textSecondary)
            Text(SRTTime(milliseconds: totalMs).displayString)
                .foregroundStyle(theme.textSecondary)
        }
        .font(theme.time)
    }
}
```

- [ ] **Step 3: TopBar (undo/redo + size + appearance controls)**

`Sources/VideoTagging/Components/TopBar.swift` (new):
```swift
import SwiftUI
import VideoTaggingCore

struct TopBar: View {
    let canUndo: Bool
    let canRedo: Bool
    let onUndo: () -> Void
    let onRedo: () -> Void
    let isListVisible: Bool
    let onToggleList: () -> Void

    @Environment(\.theme) private var theme
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        HStack(spacing: theme.s) {
            BigButton(title: Strings.undo, systemImage: "arrow.uturn.backward", action: onUndo)
                .disabled(!canUndo)
            BigButton(title: Strings.redo, systemImage: "arrow.uturn.forward", action: onRedo)
                .disabled(!canRedo)

            Spacer()

            Picker("", selection: $settings.interfaceSize) {
                Text("A").font(.system(size: 12)).tag(InterfaceSize.comfortable)
                Text("A").font(.system(size: 15)).tag(InterfaceSize.large)
                Text("A").font(.system(size: 18)).tag(InterfaceSize.extraLarge)
            }
            .pickerStyle(.segmented)
            .frame(width: 130 * theme.scale)
            .help("Interface size")

            Picker("", selection: $settings.appearance) {
                Image(systemName: "circle.lefthalf.filled").tag(AppearanceMode.system)
                Image(systemName: "sun.max").tag(AppearanceMode.light)
                Image(systemName: "moon").tag(AppearanceMode.dark)
            }
            .pickerStyle(.segmented)
            .frame(width: 130 * theme.scale)
            .help("Appearance")

            BigButton(title: isListVisible ? Strings.hideList : Strings.showList,
                      systemImage: "sidebar.right", action: onToggleList)
        }
    }
}
```

- [ ] **Step 4: Build the package (views still red is OK if you took the per-view path; but BigButton/TimeLabel/TopBar must type-check)**

Run: `swift build 2>&1 | grep -E "TopBar|BigButton|TimeLabel" || echo "shared components compile"`
Expected: no errors originating in these three files. (Other views may still error until Task 10.)

- [ ] **Step 5: Commit (allow a temporarily red tree across other views)**

```bash
git add Sources/VideoTagging/Theme/Theme.swift Sources/VideoTagging/VideoTaggingApp.swift Sources/VideoTagging/Components
git commit -m "feat(app): environment theme + restyled BigButton/TimeLabel + TopBar"
```

---

### Task 7: Restyle TransportBar

**Files:**
- Rewrite: `Sources/VideoTagging/Features/Editor/TransportBar.swift`

- [ ] **Step 1: Rewrite**

`Sources/VideoTagging/Features/Editor/TransportBar.swift` (full replacement):
```swift
import SwiftUI

struct TransportBar: View {
    let isPlaying: Bool
    let currentMs: Int
    let totalMs: Int
    let onTogglePlay: () -> Void
    let onScrub: (Int) -> Void

    @Environment(\.theme) private var theme
    @State private var hovering = false

    var body: some View {
        HStack(spacing: theme.m) {
            Button(action: onTogglePlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24 * theme.scale, weight: .semibold))
                    .frame(width: 60 * theme.scale, height: 60 * theme.scale)
                    .foregroundStyle(theme.textOnAccent)
                    .background(Circle().fill(theme.accent))
                    .shadow(color: theme.accent.opacity(0.4), radius: 10, y: 3)
                    .brightness(hovering ? 0.06 : 0)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)

            Slider(
                value: Binding(get: { Double(currentMs) }, set: { onScrub(Int($0)) }),
                in: 0...Double(max(totalMs, 1))
            )
            .tint(theme.accent)

            TimeLabel(currentMs: currentMs, totalMs: totalMs)
        }
    }
}
```

- [ ] **Step 2: Build check**

Run: `swift build 2>&1 | grep "TransportBar" || echo "TransportBar compiles"`
Expected: no TransportBar errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/VideoTagging/Features/Editor/TransportBar.swift
git commit -m "feat(app): restyle TransportBar (material, accent slider, symbol transition)"
```

---

### Task 8: Restyle SectionCardView

**Files:**
- Rewrite: `Sources/VideoTagging/Features/Editor/SectionCardView.swift`

- [ ] **Step 1: Rewrite**

`Sources/VideoTagging/Features/Editor/SectionCardView.swift` (full replacement):
```swift
import SwiftUI
import VideoTaggingCore

struct SectionCardView: View {
    let index: Int
    let section: VideoSection
    let canMoveStart: Bool
    let canMoveEnd: Bool
    let canMerge: Bool
    let text: Binding<String>
    let onCut: () -> Void
    let onMoveStart: (Int) -> Void
    let onMoveEnd: (Int) -> Void
    let onMerge: () -> Void
    let onBeginEditing: () -> Void
    let onEndEditing: () -> Void

    @Environment(\.theme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: theme.m) {
            Text(Strings.sectionHeader(index,
                                       SRTTime(milliseconds: section.start).displayString,
                                       SRTTime(milliseconds: section.end).displayString))
                .font(theme.label)
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundStyle(theme.textSecondary)

            TextEditor(text: text)
                .font(theme.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90 * theme.scale)
                .padding(theme.s)
                .background(RoundedRectangle(cornerRadius: theme.radiusSmall, style: .continuous)
                    .fill(.background.opacity(0.5)))
                .overlay(RoundedRectangle(cornerRadius: theme.radiusSmall, style: .continuous)
                    .strokeBorder(isFocused ? theme.accent : theme.separator, lineWidth: isFocused ? 2 : 1))
                .focused($isFocused)
                .animation(.easeOut(duration: 0.15), value: isFocused)
                .onChange(of: isFocused) { _, focused in
                    focused ? onBeginEditing() : onEndEditing()
                }

            BigButton(title: Strings.cutHere, prominent: true, systemImage: "scissors", action: onCut)

            HStack(spacing: theme.s) {
                if canMoveStart {
                    BigButton(title: Strings.moveStartBack) { onMoveStart(-1000) }
                    BigButton(title: Strings.moveStartForward) { onMoveStart(1000) }
                }
                if canMoveEnd {
                    BigButton(title: Strings.moveEndBack) { onMoveEnd(-1000) }
                    BigButton(title: Strings.moveEndForward) { onMoveEnd(1000) }
                }
            }
            if canMerge {
                BigButton(title: Strings.mergeWithPrevious, systemImage: "arrow.triangle.merge", action: onMerge)
            }
        }
        .padding(theme.l)
        .background(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
            .strokeBorder(theme.separator, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }
}
```

- [ ] **Step 2: Build check**

Run: `swift build 2>&1 | grep "SectionCardView" || echo "SectionCardView compiles"`
Expected: no SectionCardView errors.

- [ ] **Step 3: Commit**

```bash
git add Sources/VideoTagging/Features/Editor/SectionCardView.swift
git commit -m "feat(app): restyle SectionCardView (material card, focus ring, depth)"
```

---

### Task 9: Restyle TimelineView (+ finalize drag undo grouping)

**Files:**
- Rewrite: `Sources/VideoTagging/Features/Editor/TimelineView.swift`

- [ ] **Step 1: Rewrite with `onDragBoundary` + `onDragEnded`, themed, animated**

`Sources/VideoTagging/Features/Editor/TimelineView.swift` (full replacement):
```swift
import SwiftUI
import VideoTaggingCore

struct TimelineView: View {
    let sections: [VideoSection]
    let totalMs: Int
    let currentIndex: Int
    let onSelect: (Int) -> Void
    let onDragBoundary: (_ beforeIndex: Int, _ toMs: Int) -> Void
    let onDragEnded: () -> Void

    @Environment(\.theme) private var theme

    private func xOffset(_ ms: Int, width: CGFloat) -> CGFloat {
        CGFloat(ms) / CGFloat(max(totalMs, 1)) * width
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { i, s in
                    let left = xOffset(s.start, width: width)
                    let w = max(2, xOffset(s.end, width: width) - left)
                    RoundedRectangle(cornerRadius: 4 * theme.scale, style: .continuous)
                        .fill(fill(for: s, isCurrent: i == currentIndex))
                        .frame(width: max(0, w - 1.5))
                        .offset(x: left)
                        .onTapGesture { onSelect(i) }
                        .animation(.easeInOut(duration: 0.18), value: currentIndex)
                }
                ForEach(1..<max(sections.count, 1), id: \.self) { i in
                    let bx = xOffset(sections[i].start, width: width)
                    Capsule()
                        .fill(.white)
                        .frame(width: 3 * theme.scale, height: 44 * theme.scale)
                        .overlay(Capsule().strokeBorder(.black.opacity(0.2), lineWidth: 0.5))
                        .offset(x: bx - 1.5 * theme.scale)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .help("Drag to move the boundary")
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("timeline"))
                                .onChanged { value in
                                    onDragBoundary(i, Int(value.location.x / width * CGFloat(totalMs)))
                                }
                                .onEnded { _ in onDragEnded() }
                        )
                }
            }
            .coordinateSpace(name: "timeline")
        }
        .frame(height: 44 * theme.scale)
        .background(RoundedRectangle(cornerRadius: 6 * theme.scale, style: .continuous).fill(.quaternary))
        .clipShape(RoundedRectangle(cornerRadius: 6 * theme.scale, style: .continuous))
    }

    private func fill(for s: VideoSection, isCurrent: Bool) -> Color {
        if isCurrent { return theme.accent }
        return s.isEmpty ? theme.gap.opacity(0.5) : Color.secondary.opacity(0.5)
    }
}
```

- [ ] **Step 2: Build check**

Run: `swift build 2>&1 | grep "TimelineView" || echo "TimelineView compiles"`
Expected: no TimelineView errors (EditorView will be updated in Task 10 to pass `onDragEnded`).

- [ ] **Step 3: Commit**

```bash
git add Sources/VideoTagging/Features/Editor/TimelineView.swift
git commit -m "feat(app): restyle TimelineView (rounded blocks, capsule handles, motion)"
```

---

### Task 10: Restyle SectionListPanel, DropZoneView, ShortcutsHelp + wire EditorView (green tree)

**Files:**
- Rewrite: `Sources/VideoTagging/Features/SectionList/SectionListPanel.swift`
- Rewrite: `Sources/VideoTagging/Features/Editor/ShortcutsHelp.swift`
- Modify: `Sources/VideoTagging/Features/DropZone/DropZoneView.swift`
- Modify: `Sources/VideoTagging/Features/Editor/EditorView.swift`

- [ ] **Step 1: SectionListPanel (full replacement)**

```swift
import SwiftUI
import VideoTaggingCore

struct SectionListPanel: View {
    let sections: [VideoSection]
    let currentIndex: Int
    let onSelect: (Int) -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: theme.s) {
                    ForEach(Array(sections.enumerated()), id: \.element.id) { i, s in
                        Button { onSelect(i) } label: {
                            HStack(spacing: theme.s) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(i == currentIndex ? theme.accent : (s.isEmpty ? theme.gap.opacity(0.6) : theme.separator))
                                    .frame(width: 4)
                                VStack(alignment: .leading, spacing: theme.xs) {
                                    Text("\(i + 1) · \(SRTTime(milliseconds: s.start).displayString)–\(SRTTime(milliseconds: s.end).displayString)")
                                        .font(theme.label)
                                        .foregroundStyle(theme.textSecondary)
                                    Text(s.isEmpty ? Strings.descriptionPlaceholder : s.text)
                                        .font(theme.listItem)
                                        .foregroundStyle(s.isEmpty ? theme.textSecondary : theme.textPrimary)
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(theme.s + 4)
                            .background(RoundedRectangle(cornerRadius: theme.radiusSmall, style: .continuous)
                                .fill(i == currentIndex ? AnyShapeStyle(theme.accent.opacity(0.18)) : AnyShapeStyle(.regularMaterial)))
                            .overlay(RoundedRectangle(cornerRadius: theme.radiusSmall, style: .continuous)
                                .strokeBorder(i == currentIndex ? theme.accent.opacity(0.6) : theme.separator, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .id(s.id)
                    }
                }
                .padding(theme.m)
                .onChange(of: currentIndex) { _, newIndex in
                    guard sections.indices.contains(newIndex) else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(sections[newIndex].id, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 340 * theme.scale)
        .background(.ultraThinMaterial)
        .overlay(alignment: .leading) { Rectangle().fill(theme.separator).frame(width: 1) }
    }
}
```
Note: this restores `.id(s.id)` on the row so `scrollTo` works (the original
attached it implicitly via ForEach id; keep the explicit `.id`).

- [ ] **Step 2: ShortcutsHelp (full replacement, themed)**

```swift
import SwiftUI

struct ShortcutsHelp: View {
    let onClose: () -> Void
    @Environment(\.theme) private var theme

    private let rows: [(String, String)] = [
        ("Space", "Play / Pause"),
        ("← / →", "Jog 5 seconds"),
        ("Shift ← / →", "Jog 1 second"),
        ("C or Return", "Cut here"),
        ("↑ / ↓", "Previous / Next section"),
        (", / .", "Move end 1s back / forward"),
        ("Shift , / .", "Move start 1s back / forward"),
        ("⌘Z / ⇧⌘Z", "Undo / Redo"),
        ("Esc", "Leave the text field"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.m) {
            Text(Strings.keyboardShortcutsTitle).font(theme.title)
            VStack(alignment: .leading, spacing: theme.s) {
                ForEach(rows, id: \.0) { key, desc in
                    HStack(spacing: theme.m) {
                        Text(key).font(theme.time).frame(width: 170 * theme.scale, alignment: .leading)
                            .foregroundStyle(theme.textSecondary)
                        Text(desc).font(theme.body)
                    }
                }
            }
            BigButton(title: Strings.close, action: onClose)
        }
        .padding(theme.xl)
        .frame(minWidth: 520 * theme.scale)
        .background(.regularMaterial)
    }
}
```

- [ ] **Step 3: DropZoneView — migrate to env theme (full replacement of the body styling)**

Replace the contents of `Sources/VideoTagging/Features/DropZone/DropZoneView.swift`'s
`var body` and add `@Environment(\.theme) private var theme`. Keep the existing
`collectURLs`, `pickFiles`, and `URLBox` exactly as they are; only the visual body
changes:
```swift
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: theme.l) {
            Image(systemName: "film.stack")
                .font(.system(size: 64 * theme.scale))
                .foregroundStyle(theme.accent.gradient)
            Text(Strings.DropZone.title).font(theme.font(30, .semibold))
            Text(Strings.DropZone.subtitle)
                .font(theme.body)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
            if let errorMessage {
                Text(errorMessage)
                    .font(theme.body)
                    .foregroundStyle(theme.error)
                    .multilineTextAlignment(.center)
                    .padding(.top, theme.s)
            }
        }
        .padding(theme.xl + theme.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isTargeted ? AnyShapeStyle(theme.accent.opacity(0.12)) : AnyShapeStyle(.regularMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [10]))
                .foregroundStyle(isTargeted ? theme.accent : theme.separator)
        )
        .contentShape(Rectangle())
        .onTapGesture { pickFiles() }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            collectURLs(from: providers); return true
        }
        .padding(theme.l)
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }
```

- [ ] **Step 4: EditorView — use TopBar, env theme, pass `onDragEnded`, motion**

In `EditorView.swift`: add `@Environment(\.theme) private var theme`. Replace the
top `HStack` (added in Phase 1 Task 4) with the new `TopBar`:
```swift
                TopBar(
                    canUndo: vm.canUndo, canRedo: vm.canRedo,
                    onUndo: { vm.undo() }, onRedo: { vm.redo() },
                    isListVisible: vm.isListVisible,
                    onToggleList: { withAnimation(.easeInOut(duration: 0.2)) { vm.isListVisible.toggle() } }
                )
```
Replace all `Theme.Spacing.X` with `theme.X` (e.g. `Theme.Spacing.m` → `theme.m`,
`.l` → `theme.l`, `.s` → `theme.s`) throughout EditorView. Replace
`Theme.Colors.background` with `.background(.background)` on the root, and the
chevron `Image` colors with `theme.textSecondary`. Update the TimelineView call to
pass both drag callbacks:
```swift
                    TimelineView(
                        sections: vm.partition.sections,
                        totalMs: vm.totalMs,
                        currentIndex: vm.currentIndex,
                        onSelect: { vm.goToSection($0) },
                        onDragBoundary: { beforeIndex, toMs in vm.beginBoundaryDrag(beforeIndex: beforeIndex, toMs: toMs) },
                        onDragEnded: { vm.endBoundaryDrag() }
                    )
```
Wrap the section card / list reveal in animation so the list panel slides in:
keep the `if vm.isListVisible { SectionListPanel(...) }` but add
`.transition(.move(edge: .trailing).combined(with: .opacity))` to the panel.
Add `.environment(\.theme, theme)` is NOT needed (inherited).
Ensure `SaveStatusLabel` reads the env theme: add `@Environment(\.theme) private var theme`
to `SaveStatusLabel` and replace `Theme.Fonts.label`/`Theme.Colors.*` with `theme.*`.

- [ ] **Step 5: Full build + tests + launch smoke**

Run: `swift build` → expect ZERO warnings and **green** (all views migrated).
Run: `swift test` → expect all pass.
Run: `timeout 8 swift run VideoTagging` → launches to a restyled drop zone.
Use the temporary reproduction (optional): drop the sample in the real app to
confirm the editor renders restyled, undo/redo buttons enable/disable, size and
appearance pickers work.

- [ ] **Step 6: Commit**

```bash
git add Sources/VideoTagging
git commit -m "feat(app): restyle list/dropzone/help + wire TopBar, theme, drag-undo, motion"
```

---

### Task 11: Final verification

- [ ] **Step 1:** `swift test` → all pass (core: prior 34 + InterfaceSize + AppearanceMode + UndoStack + replaceSections).
- [ ] **Step 2:** `swift build -c release` → "Build complete!", zero warnings.
- [ ] **Step 3:** Launch release, drop the sample, and confirm by inspection:
  - Undo/Redo buttons disable when empty, enable after edits; ⌘Z / ⇧⌘Z work; a whole text-edit session and a whole drag are each one undo step.
  - Interface size picker rescales fonts/controls; appearance picker switches light/dark/system; both persist after relaunch.
  - Look is materially richer (materials, depth, motion) with no leftover hardcoded grays.
- [ ] **Step 4:** Commit any polish: `git commit -am "chore(app): polish pass for undo/settings/redesign"`.

---

## Notes for the implementer
- Phase 2 Task 5 intentionally leaves the tree red until Task 10 migrates the last
  views. If your workflow requires a green tree per commit, migrate all views in a
  single commit instead — but keep the same end state.
- Do NOT touch `SRTParser`, `SRTWriter`, or the `SectionPartition` cut/move/merge
  logic (only `replaceSections` is added). The 34 existing core tests must stay green.
- All colors must come from `theme` or native materials/semantic colors — no
  `Color(white:)` literals left in views. All copy stays in `Strings`.
- `@Environment(AppSettings.self)` requires the `@Observable` macro (already used).
