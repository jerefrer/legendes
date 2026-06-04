import SwiftUI

struct TransportBar: View {
    let isPlaying: Bool
    let currentMs: Int
    let totalMs: Int
    let onTogglePlay: () -> Void
    let onScrub: (Int) -> Void

    @Environment(\.theme) private var theme
    @State private var hovering = false

    var body: some View {
        HStack(spacing: theme.m) {
            Button(action: onTogglePlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24 * theme.scale, weight: .semibold))
                    .frame(width: 60 * theme.scale, height: 60 * theme.scale)
                    .foregroundStyle(theme.textOnAccent)
                    .background(Circle().fill(theme.accent))
                    .shadow(color: theme.accent.opacity(0.4), radius: 10, y: 3)
                    .brightness(hovering ? 0.06 : 0)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)

            Slider(
                value: Binding(get: { Double(currentMs) }, set: { onScrub(Int($0)) }),
                in: 0...Double(max(totalMs, 1))
            )
            .tint(theme.accent)

            TimeLabel(currentMs: currentMs, totalMs: totalMs)
        }
    }
}
