import CoreGraphics

public enum InterfaceSize: String, CaseIterable, Sendable {
    case comfortable
    case large
    case extraLarge

    public static let defaultValue: InterfaceSize = .comfortable

    /// Multiplier applied to fonts, control sizes, and spacing.
    public var scale: CGFloat {
        switch self {
        case .comfortable: 1.0
        case .large: 1.2
        case .extraLarge: 1.3
        }
    }

    /// Total over a persisted string, falling back to the default.
    public init(storedValue: String?) {
        self = storedValue.flatMap(InterfaceSize.init(rawValue:)) ?? .defaultValue
    }
}
