import SwiftUI

struct BigButton: View {
    let title: String
    var prominent: Bool = false
    var systemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(Theme.Fonts.button)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: prominent ? .infinity : nil)
            .foregroundStyle(prominent ? Color.white : Theme.Colors.textPrimary)
            .background(prominent ? Theme.Colors.accent : Theme.Colors.panel)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
