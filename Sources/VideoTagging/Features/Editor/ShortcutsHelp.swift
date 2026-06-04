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
