import SwiftUI

struct TransportBar: View {
    let isPlaying: Bool
    let currentMs: Int
    let totalMs: Int
    let onTogglePlay: () -> Void
    let onScrub: (Int) -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            Button(action: onTogglePlay) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26))
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.white)
                    .background(Theme.Colors.accent)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Slider(
                value: Binding(
                    get: { Double(currentMs) },
                    set: { onScrub(Int($0)) }
                ),
                in: 0...Double(max(totalMs, 1))
            )
            TimeLabel(currentMs: currentMs, totalMs: totalMs)
        }
    }
}
