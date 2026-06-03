import SwiftUI

enum Theme {
    enum Colors {
        static let accent = Color(red: 0.18, green: 0.42, blue: 0.87)
        static let panel = Color(white: 0.15)
        static let panelBorder = Color(white: 0.32)
        static let gapSection = Color(red: 0.35, green: 0.29, blue: 0.16)
        static let textPrimary = Color.white
        static let textSecondary = Color(white: 0.7)
        static let background = Color(white: 0.1)
        static let textOnAccent = Color.white
        static let error = Color.red
    }
    enum Fonts {
        static let title = Font.system(size: 22, weight: .semibold)
        static let body = Font.system(size: 22)
        static let button = Font.system(size: 20, weight: .semibold)
        static let time = Font.system(size: 26, weight: .medium).monospacedDigit()
        static let label = Font.system(size: 15, weight: .semibold)
    }
    enum Spacing {
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
    }
}
