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

            // One row when it fits; wraps to two rows otherwise (Extra Large /
            // narrow window) so nothing is ever clipped.
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
        HStack(spacing: theme.s) {
            if canMergePrevious { mergePreviousButton }
            if canMoveStart { startNudges }
            Spacer(minLength: theme.s)
            cutButton
            Spacer(minLength: theme.s)
            if canMoveEnd { endNudges }
            if canMergeNext { mergeNextButton }
        }
    }

    private var twoRows: some View {
        VStack(spacing: theme.s) {
            HStack(spacing: theme.s) {
                if canMoveStart { startNudges }
                Spacer(minLength: theme.s)
                cutButton
                Spacer(minLength: theme.s)
                if canMoveEnd { endNudges }
            }
            HStack(spacing: theme.s) {
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
                  systemImage: "arrow.up.to.line.compact", action: onMergePrevious)
    }

    private var mergeNextButton: some View {
        BigButton(title: Strings.mergeWithNext, kind: .destructive,
                  systemImage: "arrow.down.to.line.compact", action: onMergeNext)
    }

    private var startNudges: some View {
        HStack(spacing: theme.xs) {
            Text(Strings.sectionStart)
                .font(theme.label).textCase(.uppercase).kerning(0.5)
                .foregroundStyle(theme.textSecondary)
            BigButton(title: Strings.nudgeEarlier) { onMoveStart(-1000) }
            BigButton(title: Strings.nudgeLater) { onMoveStart(1000) }
        }
    }

    private var endNudges: some View {
        HStack(spacing: theme.xs) {
            BigButton(title: Strings.nudgeEarlier) { onMoveEnd(-1000) }
            BigButton(title: Strings.nudgeLater) { onMoveEnd(1000) }
            Text(Strings.sectionEnd)
                .font(theme.label).textCase(.uppercase).kerning(0.5)
                .foregroundStyle(theme.textSecondary)
        }
    }
}
