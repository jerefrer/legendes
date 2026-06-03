import SwiftUI
import VideoTaggingCore

struct TimeLabel: View {
    let currentMs: Int
    let totalMs: Int
    var body: some View {
        Text("\(SRTTime(milliseconds: currentMs).displayString) / \(SRTTime(milliseconds: totalMs).displayString)")
            .font(Theme.Fonts.time)
            .foregroundStyle(Theme.Colors.textPrimary)
    }
}
