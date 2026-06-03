import SwiftUI

struct ShortcutsHelp: View {
    let onClose: () -> Void
    private let rows: [(String, String)] = [
        ("Space", "Play / Pause"),
        ("← / →", "Jog 5 seconds"),
        ("Shift ← / →", "Jog 1 second"),
        ("C or Return", "Cut here"),
        ("↑ / ↓", "Previous / Next section"),
        (", / .", "Move end 1s back / forward"),
        ("Shift , / .", "Move start 1s back / forward"),
        ("Esc", "Leave the text field"),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Keyboard shortcuts").font(.system(size: 26, weight: .semibold))
            ForEach(rows, id: \.0) { key, desc in
                HStack {
                    Text(key).font(Theme.Fonts.time).frame(width: 160, alignment: .leading)
                    Text(desc).font(Theme.Fonts.body)
                }
            }
            BigButton(title: "Close", action: onClose)
        }
        .padding(Theme.Spacing.l)
        .frame(minWidth: 480)
    }
}
