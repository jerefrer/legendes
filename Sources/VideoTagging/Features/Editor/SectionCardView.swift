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

            // Primary action — visible but not full width.
            HStack {
                Spacer(minLength: 0)
                BigButton(title: Strings.cutHere, kind: .primary, systemImage: "scissors", action: onCut)
                    .frame(maxWidth: 440)
                Spacer(minLength: 0)
            }

            // Boundary nudges: start on the left, end on the right (spatial mapping).
            HStack(alignment: .bottom, spacing: theme.l) {
                if canMoveStart {
                    boundaryGroup(title: Strings.sectionStart,
                                  onEarlier: { onMoveStart(-1000) },
                                  onLater: { onMoveStart(1000) })
                }
                Spacer(minLength: 0)
                if canMoveEnd {
                    boundaryGroup(title: Strings.sectionEnd,
                                  onEarlier: { onMoveEnd(-1000) },
                                  onLater: { onMoveEnd(1000) })
                }
            }

            // Removing a cut — explicit about which neighbour it joins.
            if canMergePrevious || canMergeNext {
                HStack(spacing: theme.s) {
                    if canMergePrevious {
                        BigButton(title: Strings.mergeWithPrevious, kind: .destructive,
                                  systemImage: "arrow.up.to.line.compact", action: onMergePrevious)
                    }
                    if canMergeNext {
                        BigButton(title: Strings.mergeWithNext, kind: .destructive,
                                  systemImage: "arrow.down.to.line.compact", action: onMergeNext)
                    }
                }
            }
        }
        .padding(theme.l)
        .background(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
            .strokeBorder(theme.separator, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }

    private func boundaryGroup(title: String, onEarlier: @escaping () -> Void, onLater: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: theme.xs) {
            Text(title)
                .font(theme.label)
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundStyle(theme.textSecondary)
            HStack(spacing: theme.xs) {
                BigButton(title: Strings.nudgeEarlier, action: onEarlier)
                BigButton(title: Strings.nudgeLater, action: onLater)
            }
        }
    }
}
