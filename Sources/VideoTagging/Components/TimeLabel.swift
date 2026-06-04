import SwiftUI
import VideoTaggingCore

struct TimeLabel: View {
    let currentMs: Int
    let totalMs: Int
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: theme.xs) {
            Text(SRTTime(milliseconds: currentMs).displayString)
                .foregroundStyle(theme.textPrimary)
            Text("/").foregroundStyle(theme.textSecondary)
            Text(SRTTime(milliseconds: totalMs).displayString)
                .foregroundStyle(theme.textSecondary)
        }
        .font(theme.time)
    }
}
