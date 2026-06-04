import SwiftUI
import VideoTaggingCore

struct SectionCardView: View {
    let index: Int
    let section: VideoSection
    let canMoveStart: Bool
    let canMoveEnd: Bool
    let canMergePrevious: Bool
    let canMergeNext: Bool
    let text: Binding<String>
    let onCut: () -> Void
    let onMoveStart: (Int) -> Void
    let onMoveEnd: (Int) -> Void
    let onMergePrevious: () -> Void
    let onMergeNext: () -> Void
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

            // One row when it fits; wraps to two otherwise. Cut here is always
            // centered (overlaid), independent of which side buttons exist.
            ViewThatFits(in: .horizontal) {
                oneRow
                twoRows
            }
        }
        .padding(theme.l)
        .background(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
            .strokeBorder(theme.separator, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }

    private var oneRow: some View {
        ZStack {
            cutButton
            HStack(spacing: theme.l) {
                if canMergePrevious { mergePreviousButton }
                if canMoveStart { startNudges }
                Spacer(minLength: 200 * theme.scale)
                if canMoveEnd { endNudges }
                if canMergeNext { mergeNextButton }
            }
        }
    }

    private var twoRows: some View {
        VStack(spacing: theme.s) {
            ZStack {
                cutButton
                HStack(spacing: theme.l) {
                    if canMoveStart { startNudges }
                    Spacer(minLength: 180 * theme.scale)
                    if canMoveEnd { endNudges }
                }
            }
            HStack(spacing: theme.l) {
                if canMergePrevious { mergePreviousButton }
                Spacer(minLength: 0)
                if canMergeNext { mergeNextButton }
            }
        }
    }

    private var cutButton: some View {
        BigButton(title: Strings.cutHere, kind: .primary, systemImage: "scissors", action: onCut)
    }

    private var mergePreviousButton: some View {
        BigButton(title: Strings.mergeWithPrevious, kind: .destructive,
                  systemImage: "arrow.left.to.line", action: onMergePrevious)
    }

    private var mergeNextButton: some View {
        BigButton(title: Strings.mergeWithNext, kind: .destructive,
                  systemImage: "arrow.right.to.line", iconTrailing: true, action: onMergeNext)
    }

    private var startNudges: some View {
        nudgeGroup(label: Strings.sectionStart,
                   onEarlier: { onMoveStart(-1000) },
                   onLater: { onMoveStart(1000) })
    }

    private var endNudges: some View {
        nudgeGroup(label: Strings.sectionEnd,
                   onEarlier: { onMoveEnd(-1000) },
                   onLater: { onMoveEnd(1000) })
    }

    /// `[ − 1 s ]  LABEL  [ + 1 s ]` — the boundary name centered between its
    /// two nudge buttons, symmetric for both start and end.
    private func nudgeGroup(label: String, onEarlier: @escaping () -> Void, onLater: @escaping () -> Void) -> some View {
        HStack(spacing: theme.s) {
            BigButton(title: Strings.nudgeEarlier, action: onEarlier)
            Text(label)
                .font(theme.label).textCase(.uppercase).kerning(0.5)
                .foregroundStyle(theme.textSecondary)
                .fixedSize()
            BigButton(title: Strings.nudgeLater, action: onLater)
        }
    }
}
