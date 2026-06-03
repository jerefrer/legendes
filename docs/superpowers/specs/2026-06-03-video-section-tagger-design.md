# Video Section Tagger — Design

**Date:** 2026-06-03
**Status:** Approved

## Purpose

A native macOS app for tagging the contents of a video by section: dividing the
timeline into contiguous segments and giving each a textual description ("from
this moment to that moment, we see X"). The descriptions are stored as SubRip
(`.srt`) subtitle files, so the output is compatible with standard tools.

The app exists for one very specific need: a person over 80, comfortable on a
Mac only when things stay simple, must be able to **review and correct existing
section files** (adjust descriptions, adjust where each section starts and ends)
and **create new section files from scratch**. The design priority is therefore
radical simplicity: large video, large text, large buttons, few things on screen
at once, keyboard shortcuts for those who want them. It must be markedly simpler
than a subtitle editor like Subtitle Edit.

The interface is **English only** so the project can be useful as open source.
Section descriptions themselves stay in whatever language the source uses
(English in the sample data).

## Core Model Decisions

### Contiguous sections (cut points, not independent clips)

The video is partitioned into segments that touch end-to-end: every instant
belongs to exactly one section. `section[i].end == section[i+1].start`. The
first section starts at 0; the last ends at the video duration. Internally what
matters is the set of **cut points** between sections.

Consequence: moving the end of a section moves the start of the next section —
it is the same cut. There are never gaps or overlaps to reason about. This is
the simplest possible mental model for the end user.

### Empty descriptions represent "undescribed" passages

A section whose description is empty is a "gap" — a passage the user chose not to
describe. Empty-description sections are **automatically excluded from the `.srt`
export** (an empty subtitle is meaningless). The user simply leaves the text
blank; the exported `.srt` then naturally contains the gaps in the right places.
No manual per-section "exclude" toggle.

### Section data

```
Section = { start: Duration, end: Duration, text: String }
Project = { videoURL, srtURL, sections: [Section] }
```

Times are stored at millisecond precision (matching `.srt`); displayed as `mm:ss`
(or `h:mm:ss` past one hour).

## File Handling

### Opening — a drop zone

At launch (and reachable later via menu / button) the app shows a **drop zone**.

- **Drop one video file** → open the video; look for a sibling `.srt` of the same
  base name. If found, load its sections. If not, start with a **single empty
  section** spanning the whole video, which the user will cut up as they go.
- **Drop one `.srt` file** → look for a sibling video of the same base name and
  open it. If none is found, show a friendly, informative error (e.g. "I found
  the subtitles but not the video next to them. Drop the video too, or click to
  pick both files.").
- **Two files** (dropped together, or chosen via the picker) → pair video + `.srt`
  explicitly, even if their names differ.
- Clicking the drop zone opens a file picker allowing **up to 2 files** to be
  selected at once.
- Other cases handled with clear messages: no video among the files, two videos,
  unknown file type.

### Saving — automatic

The app **auto-saves** continuously to the `.srt` (next to the video, or next to
the source `.srt`). A clear status indicator shows "Saved ✓" / "Saving…". There
is no explicit save button the user must remember.

### Backups

On opening an existing `.srt`, the app writes a timestamped copy into a
`.backups/` subfolder beside it, so a bad edit can always be recovered.

## Main UI — Layout A with a hideable side panel

A single focused window. Only the current section is edited at a time.

- **Video** — large `AVPlayer` view.
- **Transport bar** — large Play/Pause button, a scrub bar, and a large time
  readout `12:27 / 1:02:26`.
- **Current Section card** — section number + time range, a large editable
  description field, and the actions:
  - **✂ Cut here** (large primary button) — split the current section at the
    playhead. The earlier portion keeps the existing description; the new later
    portion starts empty (the new scene to describe).
  - **Move start ◀ ▶** and **Move end ◀ ▶** — nudge the boundary by ±1 s. Moving
    a section's start also moves the previous section's end (same cut). The first
    section's start (0) and the last section's end (video duration) are fixed.
  - **Merge / Delete cut** — remove the current cut (merge with a neighbor), to
    undo an accidental cut.
- **Timeline** — contiguous blocks along the bottom; current section highlighted;
  empty ("gap") sections shown in a distinct color; draggable handles between
  blocks; ‹ › arrows for previous / next section.
- **Side panel (hideable)** — the full section list in large type; clicking a row
  jumps to that section. Toggled by a button.

## Keyboard Shortcuts (initial set, adjustable later)

- `Space` — Play / Pause
- `←` / `→` — jog video −5 s / +5 s; `⇧←` / `⇧→` — −1 s / +1 s
- `C` or `Return` — Cut here
- `↑` / `↓` — previous / next section
- `,` / `.` — Move end ◀ / ▶ (1 s); `⇧,` / `⇧.` — Move start ◀ / ▶
- Click description to edit; `Esc` to leave the text field
- A `?` help panel lists all shortcuts in large type.

## SRT Import / Export

- **Import** — a tolerant SRT parser. The sample file has millisecond-scale gaps
  and overlaps from manual editing; these are normalized into a contiguous
  partition by aligning each `start` to the previous `end`.
- **Export** — empty-text sections excluded; remaining sections renumbered
  sequentially; timecodes `HH:MM:SS,mmm`; multi-line descriptions preserved.
- The round-trip "import the sample `.srt` → re-export" is a regression anchor.

## Architecture (SwiftUI, MVVM per project rules)

```
VideoTagging/
  App/                 // entry point, window
  Theme/               // Colors, Typography, Spacing (large by default)
  Constants/           // Strings.swift (all UI copy, English)
  Models/              // Section, Project
  Services/            // SRTParser, SRTWriter, FilePairing, AutosaveService, BackupService
  Features/
    Editor/            // EditorView + EditorViewModel (project, playback, current section)
    DropZone/          // DropZoneView + ViewModel
    SectionList/       // hideable side panel
  Components/          // BigButton, TimeLabel, Timeline, SectionCard
```

- `EditorViewModel` is `@MainActor @Observable`: owns the project, the
  `AVPlayer`, the current section index, and triggers auto-save.
- Services are testable independently (SRT parser/writer especially).
- No hardcoded colors/fonts/strings in views — everything comes from
  `Theme/` and `Constants/Strings.swift`.

## Error Handling

- File pairing failures → friendly in-app messages (never a crash or a raw
  error). Each failure mode (missing video, missing srt, too many files, wrong
  type) has its own clear message.
- Malformed `.srt` → parse what is valid, normalize, and report how many entries
  were recovered rather than failing outright.
- Auto-save failures (e.g. permissions) → surfaced via the save indicator with a
  clear message; in-memory work is never lost silently.

## Testing

- Unit tests for `SRTParser` (including the real sample file, gaps/overlaps),
  `SRTWriter` (round-trip, empty exclusion, renumbering), the contiguous-partition
  operations (cut / merge / move-boundary preserve the invariant), and file
  pairing.
- The sample-file round-trip is the primary regression test.

## Phases

1. **Model + SRT parse/write + tests** — core logic, no UI.
2. **Video player + cut / move / merge + section card + auto-save.**
3. **Drop zone + file pairing + errors + backups.**
4. **Timeline + section list panel + keyboard shortcuts + large-UI polish.**
5. **(Last, optional, revertable)** scene-change detection + magnetic snapping of
   handles and "Cut here" to detected cuts. Implemented as a toggleable layer so
   it can be removed cleanly if it proves unreliable on this old footage.

## Out of Scope (YAGNI)

No export formats other than `.srt`; no multi-project / tabs; no user font-size
setting (large is fixed); no frame-accurate cutting; no cloud/sync.

## Open Item

Confirm the macOS version on the end user's Mac. Target is macOS 14+ (Sonoma);
lower the deployment target if their machine is older.
