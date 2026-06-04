import AppKit
import VideoTaggingCore

extension AppearanceMode {
    /// The AppKit appearance to apply app-wide. `nil` means "follow the system"
    /// (reliably reverts to the OS appearance, unlike `.preferredColorScheme(nil)`
    /// which does not restore system appearance on macOS once a scheme was forced).
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}
