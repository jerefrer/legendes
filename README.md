# Légendes

A native macOS app for tagging a video by section: dividing the timeline into
contiguous, described segments stored as a SubRip (`.srt`) subtitle file. Built
for a simple, large, forgiving interface — open a video (and optionally its
`.srt`), play, cut sections, describe them, adjust boundaries; everything
auto-saves.

## Requirements

- macOS 14 or later
- Xcode 16+ / Swift 6 toolchain (to build)

## Run during development

```bash
swift run VideoTagging
```

Then drop a video (and optionally its `.srt`) onto the window, or click to pick
files.

## Build the double-clickable app

```bash
./scripts/build-app.sh
open "Légendes.app"
```

This produces `Légendes.app` (shown as "Légendes" in the Dock and menu bar).

## Tests

```bash
swift test
```

The pure logic (SRT parsing/writing, the contiguous-section model, undo, file
pairing) lives in the `VideoTaggingCore` library and is unit-tested; the
SwiftUI app target is `VideoTagging`.
