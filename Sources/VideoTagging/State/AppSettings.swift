import Foundation
import Observation
import VideoTaggingCore

@MainActor
@Observable
final class AppSettings {
    var appearance: AppearanceMode {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private let defaults: UserDefaults
    private enum Keys {
        static let appearance = "appearanceMode"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.appearance = AppearanceMode(storedValue: defaults.string(forKey: Keys.appearance))
    }
}
