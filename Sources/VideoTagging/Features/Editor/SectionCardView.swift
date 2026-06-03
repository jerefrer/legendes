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

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(Strings.sectionHeader(index, SRTTime(milliseconds: section.start).displayString, SRTTime(milliseconds: section.end).displayString))
                .font(Theme.Fonts.label)
                .foregroundStyle(Theme.Colors.textSecondary)

            TextEditor(text: text)
                .font(Theme.Fonts.body)
                .frame(minHeight: 80)
                .padding(8)
                .background(Theme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .focused($isFocused)
                .onChange(of: isFocused) { _, focused in
                    focused ? onBeginEditing() : onEndEditing()
                }

            BigButton(title: Strings.cutHere, prominent: true, systemImage: "scissors", action: onCut)

            HStack(spacing: Theme.Spacing.s) {
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
        .padding(Theme.Spacing.m)
        .background(Theme.Colors.panel)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.accent, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
