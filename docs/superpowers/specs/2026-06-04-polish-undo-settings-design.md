# Polish, Undo/Redo & Display Settings — Design

**Date:** 2026-06-04
**Status:** Approved
**Builds on:** `2026-06-03-video-section-tagger-design.md` (phases 1–4 shipped)

## Purpose

Three enhancements to the shipped Video Section Tagger:

1. **Undo / Redo** — the non-technical user needs visible Undo/Redo *buttons* (not
   just keyboard shortcuts), covering every edit. `⌘Z` was reported "not working"
   because the user pressed `Ctrl+Z`; on macOS it's `⌘Z`, and nothing was wired
   anyway.
2. **Display settings** — an in-app **interface size** control (Comfortable /
   Large / Extra Large) so the app suits both the 80-year-old primary user and
   people who don't want it oversized, plus an **appearance** control
   (System / Light / Dark). Both persist across launches.
3. **Visual redesign** — elevate the look from "functional but very basic" to a
   refined, native macOS aesthetic. The layout stays; the material, depth,
   typography, spacing, and motion change.

## 1. Visual Direction

One-sentence brief: **a refined, calm, native macOS app with real depth and
materials — never a flat "bootstrap" look.**

- **Adapts to system appearance** with semantic colors and **native materials**
  (translucent/vibrant panels, like Notes / Final Cut) rather than hardcoded grays.
- **SF Pro typography** with genuine hierarchy: titles, small-caps secondary
  labels, tabular-figure time readouts. Consistent 4/8 pt spacing grid.
- **Subtle depth:** Apple-style continuous rounded corners, soft shadows, thin
  luminous strokes; no harsh fills.
- **One disciplined accent** (the system accent color) with polished
  hover / pressed / focus states.
- **Smooth motion:** gentle transitions on section selection, list-panel
  reveal, and state changes (play/pause, "Saved ✓").
- Timeline and section card reworked as elegant components (rounded blocks,
  clear draggable-handle affordance, animated highlight).

## 2. Undo / Redo

- **Covers every model edit:** cut, merge, move-boundary (buttons *and* drag),
  and description text edits.
- **Text edits are coalesced:** everything typed during one editing session of a
  description collapses into a **single** undo step (not one per keystroke).
- **One undo step per boundary drag:** a whole drag gesture is one step (snapshot
  taken at drag start, not per frame).
- **Two large Undo / Redo buttons** in the top bar (icon + label), **disabled**
  when there is nothing to undo/redo. This is the primary mechanism.
- Also wires standard macOS shortcuts **⌘Z / ⇧⌘Z**.
- **Implementation:** a snapshot stack (not AppKit `UndoManager`). State snapshot
  = `(sections, currentIndex)`. The stack lives in `VideoTaggingCore` as a tested,
  pure `UndoStack`, with a bounded depth (e.g. 100). The view model records a
  snapshot before each discrete edit, and once at the start of a text-editing
  session / boundary drag.

## 3. Display Settings

- **Interface size:** `InterfaceSize` = `.comfortable | .large | .extraLarge`,
  each mapping to a scale factor (≈ 1.0 / 1.2 / 1.45) applied to fonts, control
  sizes, and spacing. **Default: Comfortable.**
- **Appearance:** `AppearanceMode` = `.system | .light | .dark`, mapped to a
  SwiftUI `ColorScheme?` applied via `.preferredColorScheme`. **Default: System.**
- Both surfaced via small segmented controls in the top bar (and the standard
  app menu). Discreet but findable.
- **Persisted** with `@AppStorage` (UserDefaults), keyed by raw values.

## 4. Architecture

- **`AppSettings`** (`@Observable`, `@AppStorage`-backed) holds `interfaceSize`
  and `appearance`. Created at the app root and injected into the environment.
- **Scaled, appearance-aware Theme.** The static `Theme` becomes a value resolved
  from the current scale and provided through the environment
  (`@Environment(\.theme)`). Fonts and spacing are multiplied by the size scale;
  colors are semantic / material-based so they adapt to light/dark automatically.
  Views read `theme` from the environment instead of referencing static tokens.
  (The visual redesign rewrites the view layer anyway, so this is not extra churn.)
- **`UndoStack`** in `VideoTaggingCore`: pure, generic over a snapshot type,
  `record/undo/redo/canUndo/canRedo`, bounded depth. Unit-tested.
- **`EditorViewModel`** gains: an `UndoStack<EditorSnapshot>`, `recordUndo()`
  called before discrete edits, `beginTextEditing` records once, drag start
  records once; `undo()` / `redo()` apply snapshots; `canUndo` / `canRedo`
  drive the buttons. The SRT/partition core is unchanged.
- Redesign touches `Theme/`, `Components/`, and `Features/` views; the SRT parser,
  writer, and `SectionPartition` are untouched.

## Error Handling

- Settings reads/writes are total (enums with safe fallback to defaults on an
  unrecognized stored value).
- Undo/redo on an empty stack is a no-op (buttons disabled; shortcuts ignored).
- Applying a snapshot clamps `currentIndex` into range (defensive, matches the
  existing clamp in `currentSection`).

## Testing

- `UndoStackTests`: record/undo/redo ordering, redo cleared on new record,
  bounded depth eviction, canUndo/canRedo flags.
- `AppSettings` raw-value round-trip and fallback-to-default on bad input.
- Snapshot apply clamps out-of-range index.
- The existing 34 core tests must stay green; redesign must not change behavior.

## Phases

1. **Settings model + scaled/appearance-aware Theme** (model + environment wiring).
2. **UndoStack (Core, TDD) + view-model integration** (record/undo/redo, coalescing).
3. **Visual redesign of components & feature views** + Undo/Redo buttons + the
   size/appearance controls in the top bar + motion.

## Out of Scope (YAGNI)

No multiple custom themes, no per-element font settings, no color editor, no
undo history UI beyond the two buttons.
