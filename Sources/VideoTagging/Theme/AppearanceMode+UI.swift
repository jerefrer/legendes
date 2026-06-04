import SwiftUI
import VideoTaggingCore

extension AppearanceMode {
    /// nil means "follow the system".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
