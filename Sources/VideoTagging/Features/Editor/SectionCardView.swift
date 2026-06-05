import SwiftUI
import VideoTaggingCore

/// Reports the card's minimum height (description at its min + the action
/// buttons, which wrap to two rows on narrow widths) so the editor can cap the
/// video and never let the card slide under the timeline.
struct CardMinHeightKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct SectionCardView: View {
    let index: Int
    let section: VideoSection
    let canMoveStart: Bool
    let canMoveEnd: Bool
    let canMergePrevious: Bool
    let canMergeNext: Bool
    let canCut: Bool
    let optionDown: Bool
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
        .background(cardMinProbe)
    }

    /// Hidden, same-width replica with the description at its minimum height,
    /// measured to report the card's true minimum (incl. button wrapping).
    private var cardMinProbe: some View {
        VStack(alignment: .leading, spacing: theme.m) {
            Text(Strings.sectionHeader(index,
                                       SRTTime(milliseconds: section.start).displayString,
                                       SRTTime(milliseconds: section.end).displayString))
                .font(theme.label).textCase(.uppercase).kerning(0.5)
            Color.clear.frame(height: 80 * theme.scale + 2 * theme.s)   // TextEditor min + its padding
            twoRows   // tallest arrangement → reserve room so the card never slides under the timeline
        }
        .padding(theme.l)
        .fixedSize(horizontal: false, vertical: true)
        .hidden()
        .background(GeometryReader { p in
            Color.clear.preference(key: CardMinHeightKey.self, value: p.size.height)
        })
    }

    // The left/right button clusters. Either may be empty (first section has no
    // start nudges / merge-previous; last section has no end nudges / merge-next).
    private var leftGroup: some View {
        HStack(spacing: theme.l) {
            if canMergePrevious { mergePreviousButton }
            if canMoveStart { startNudges }
        }
    }

    private var rightGroup: some View {
        HStack(spacing: theme.l) {
            if canMoveEnd { endNudges }
            if canMergeNext { mergeNextButton }
        }
    }

    /// One side, in a slot sized to the *wider* of the two groups: each slot holds
    /// a hidden copy of both groups, so left and right slots have identical width.
    /// Equal slots keep the overlaid Cut button screen-centered, and a side button
    /// can never reach far enough to overlap it.
    private func slot(_ alignment: Alignment, @ViewBuilder _ visible: () -> some View) -> some View {
        ZStack(alignment: alignment) {
            leftGroup.hidden()
            rightGroup.hidden()
            visible()
        }
    }

    private var oneRow: some View {
        ZStack {
            cutButton
            // A hidden Cut between the two slots reserves Cut's real width in the
            // layout flow, so ViewThatFits measures `2 × widerSide + cut` and wraps
            // at the correct point — at every interface size, with no overlap.
            HStack(spacing: theme.l) {
                slot(.leading) { leftGroup }
                cutButton.hidden()
                slot(.trailing) { rightGroup }
            }
        }
    }

    /// Nudge-only side, sized to a nudge group (start ≈ end) so row 1 of the
    /// wrapped layout keeps Cut centered without overlap, even when a side is empty.
    private func nudgeSlot(_ alignment: Alignment, @ViewBuilder _ visible: () -> some View) -> some View {
        ZStack(alignment: alignment) {
            startNudges.hidden()
            endNudges.hidden()
            visible()
        }
    }

    private var twoRows: some View {
        VStack(spacing: theme.s) {
            ZStack {
                cutButton
                HStack(spacing: theme.l) {
                    nudgeSlot(.leading) { if canMoveStart { startNudges } }
                    cutButton.hidden()
                    nudgeSlot(.trailing) { if canMoveEnd { endNudges } }
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
            .disabled(!canCut)
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
        nudgeGroup(label: Strings.sectionStart, onMove: onMoveStart)
    }

    private var endNudges: some View {
        nudgeGroup(label: Strings.sectionEnd, onMove: onMoveEnd)
    }

    // Hold Option for 0.1 s steps instead of 1 s.
    private var step: Int { optionDown ? 100 : 1000 }
    private var earlierLabel: String { optionDown ? Strings.nudgeEarlierFine : Strings.nudgeEarlier }
    private var laterLabel: String { optionDown ? Strings.nudgeLaterFine : Strings.nudgeLater }

    /// `[ − 1 s ]  LABEL  [ + 1 s ]` — the boundary name centered between its
    /// two nudge buttons, symmetric for both start and end. Fixed button width
    /// so the label doesn't reflow when it grows to "− 0.1 s".
    private func nudgeGroup(label: String, onMove: @escaping (Int) -> Void) -> some View {
        HStack(spacing: theme.s) {
            BigButton(title: earlierLabel, tint: theme.accent, emphasized: optionDown) { onMove(-step) }
                .frame(width: 92 * theme.scale)
            Text(label)
                .font(theme.label).textCase(.uppercase).kerning(0.5)
                .foregroundStyle(theme.textSecondary)
                .fixedSize()
            BigButton(title: laterLabel, tint: theme.accent, emphasized: optionDown) { onMove(step) }
                .frame(width: 92 * theme.scale)
        }
    }
}
