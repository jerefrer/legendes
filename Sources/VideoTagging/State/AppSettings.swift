import Foundation
import Observation
import VideoTaggingCore

@MainActor
@Observable
final class AppSettings {
    var interfaceSize: InterfaceSize {
        didSet { defaults.set(interfaceSize.rawValue, forKey: Keys.size) }
    }
    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private let defaults: UserDefaults
    private enum Keys {
        static let size = "interfaceSize"
        static let appearance = "appearanceMode"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.interfaceSize = InterfaceSize(storedValue: defaults.string(forKey: Keys.size))
        self.appearance = AppearanceMode(storedValue: defaults.string(forKey: Keys.appearance))
    }
}
