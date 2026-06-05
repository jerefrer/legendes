enum Strings {
    static let appName = "Légendes"
    static let cutHere = "Cut here"
    static let sectionStart = "Start"
    static let sectionEnd = "End"
    static let nudgeEarlier = "− 1 s"
    static let nudgeLater = "+ 1 s"
    static let nudgeEarlierFine = "− 0.1 s"
    static let nudgeLaterFine = "+ 0.1 s"
    static let mergeWithPrevious = "Merge with previous"
    static let mergeWithNext = "Merge with next"
    static let descriptionPlaceholder = "Describe what is shown here…"
    static let saved = "Saved"
    static let saving = "Saving…"
    static let saveFailed = "Could not save"
    static let showList = "Show list"
    static let hideList = "Hide list"
    static let previousSection = "Previous"
    static let nextSection = "Next"
    static let keyboardShortcutsTitle = "Keyboard shortcuts"
    static let close = "Close"
    static let undo = "Undo"
    static let redo = "Redo"
    static let checkForUpdates = "Check for Updates…"

    static func sectionHeader(_ index: Int, _ start: String, _ end: String) -> String {
        "SECTION \(index + 1)  ·  \(start) – \(end)"
    }

    enum DropZone {
        static let title = "Drop a video here"
        static let subtitle = "Drop a video (and optionally its .srt), or click to choose files."
        static let videoNotFound = "I found the subtitles but not the video next to them. Drop the video too, or click to pick both files."
        static let tooManyVideos = "Please drop only one video at a time."
        static let noUsable = "That doesn't look like a video or a .srt file. Try again."
        static let videoUnreadable = "I couldn't read that video file. It may be in an unsupported format or damaged."
    }
}
