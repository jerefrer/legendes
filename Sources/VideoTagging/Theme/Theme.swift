import SwiftUI

/// Design system resolved from the current interface scale. Colors are semantic
/// so they adapt to light/dark automatically; panels use native materials.
struct Theme: Sendable {
    let scale: CGFloat

    // Spacing (4/8pt grid, scaled)
    var xs: CGFloat { 4 * scale }
    var s: CGFloat { 8 * scale }
    var m: CGFloat { 16 * scale }
    var l: CGFloat { 24 * scale }
    var xl: CGFloat { 36 * scale }

    // Corner radii (continuous style applied at call sites)
    var radius: CGFloat { 14 * scale }
    var radiusSmall: CGFloat { 10 * scale }
    var controlHeight: CGFloat { 52 * scale }

    // Typography (SF Pro)
    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size * scale, weight: weight)
    }
    var title: Font { font(24, .semibold) }
    var body: Font { font(20) }
    var button: Font { font(18, .semibold) }
    var time: Font { .system(size: 26 * scale, weight: .semibold, design: .rounded).monospacedDigit() }
    var label: Font { font(12, .semibold) }
    var listItem: Font { font(16) }

    // Semantic colors (auto light/dark)
    var accent: Color { .accentColor }
    var textPrimary: Color { .primary }
    var textSecondary: Color { .secondary }
    var textOnAccent: Color { .white }
    var error: Color { .red }
    var separator: Color { .primary.opacity(0.08) }
    /// Tint for "gap"/empty sections on the timeline & list.
    var gap: Color { .orange }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme(scale: 1.0)
}
extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
