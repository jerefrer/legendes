import SwiftUI

struct BigButton: View {
    let title: String
    var prominent: Bool = false
    var systemImage: String? = nil
    let action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.s) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(theme.button)
            .padding(.vertical, theme.s + 6)
            .padding(.horizontal, theme.m)
            .frame(maxWidth: prominent ? .infinity : nil, minHeight: theme.controlHeight)
            .foregroundStyle(prominent ? theme.textOnAccent : theme.textPrimary)
            .background {
                RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                    .fill(prominent ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.regularMaterial))
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                    .strokeBorder(theme.separator, lineWidth: prominent ? 0 : 1)
            }
            .shadow(color: .black.opacity(prominent && isEnabled ? 0.18 : 0), radius: 8, y: 3)
            .brightness(hovering && isEnabled ? 0.05 : 0)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}
