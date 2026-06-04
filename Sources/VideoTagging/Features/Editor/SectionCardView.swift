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
                .frame(minHeight: 80 * theme.scale, maxHeight: .infinity)
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
