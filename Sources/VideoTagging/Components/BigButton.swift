import SwiftUI

struct BigButton: View {
    enum Kind { case primary, neutral, destructive }

    let title: String
    var kind: Kind = .neutral
    var systemImage: String? = nil
    var iconTrailing: Bool = false
    /// When set (with `.neutral`), the button uses a coloured tint instead of
    /// the plain material — `emphasized` deepens it (e.g. while a modifier is held).
    var tint: Color? = nil
    var emphasized: Bool = false
    let action: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.s) {
                if let systemImage, !iconTrailing { Image(systemName: systemImage) }
                Text(title)
                if let systemImage, iconTrailing { Image(systemName: systemImage) }
            }
            .font(theme.button)
            .padding(.vertical, theme.s + 6)
            .padding(.horizontal, theme.m)
            .frame(minHeight: theme.controlHeight)
            .foregroundStyle(foreground)
            .background {
                RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                    .fill(fill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                    .strokeBorder(border, lineWidth: kind == .primary ? 0 : 1)
            }
            .shadow(color: .black.opacity(kind == .primary && isEnabled ? 0.18 : 0), radius: 8, y: 3)
            .brightness(hovering && isEnabled ? 0.05 : 0)
            .opacity(isEnabled ? 1 : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.easeOut(duration: 0.12), value: emphasized)
    }

    private var foreground: Color {
        switch kind {
        case .primary: theme.textOnAccent
        case .destructive: theme.error
        case .neutral: tint ?? theme.textPrimary
        }
    }

    private var fill: AnyShapeStyle {
        switch kind {
        case .primary: AnyShapeStyle(theme.accent)
        case .destructive: AnyShapeStyle(theme.error.opacity(0.12))
        case .neutral:
            if let tint { AnyShapeStyle(tint.opacity(emphasized ? 0.30 : 0.16)) }
            else { AnyShapeStyle(.regularMaterial) }
        }
    }

    private var border: Color {
        switch kind {
        case .primary: .clear
        case .destructive: theme.error.opacity(0.4)
        case .neutral: tint.map { $0.opacity(emphasized ? 0.7 : 0.4) } ?? theme.separator
        }
    }
}
