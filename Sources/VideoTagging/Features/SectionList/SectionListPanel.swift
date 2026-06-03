import SwiftUI
import VideoTaggingCore

struct SectionListPanel: View {
    let sections: [VideoSection]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.s) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { i, s in
                    Button { onSelect(i) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(i + 1) · \(SRTTime(milliseconds: s.start).displayString)–\(SRTTime(milliseconds: s.end).displayString)")
                                .font(Theme.Fonts.label)
                                .foregroundStyle(Theme.Colors.textSecondary)
                            Text(s.isEmpty ? Strings.descriptionPlaceholder : s.text)
                                .font(.system(size: 17))
                                .foregroundStyle(s.isEmpty ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(i == currentIndex ? Theme.Colors.accent.opacity(0.25) : Theme.Colors.panel)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.Spacing.m)
        }
        .frame(width: 320)
        .background(Color(white: 0.08))
    }
}
