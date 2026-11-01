import Foundation

/// Encodes controller settings in the supplied preferences domain, preserving the existing key and JSON schema.
struct ControllerSettingsStore {
    static let defaultsKey = "AppleIIControllerMapping"
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> ControllerMapping {
        return ControllerMapping.decoded(defaults.data(forKey: Self.defaultsKey))
    }

    func save(_ mapping: ControllerMapping) {
        if let data = try? JSONEncoder().encode(mapping) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
