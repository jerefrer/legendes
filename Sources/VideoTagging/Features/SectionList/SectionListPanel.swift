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
