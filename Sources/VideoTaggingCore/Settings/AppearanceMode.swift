public enum AppearanceMode: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    public static let defaultValue: AppearanceMode = .system

    public init(storedValue: String?) {
        self = storedValue.flatMap(AppearanceMode.init(rawValue:)) ?? .defaultValue
    }
}
