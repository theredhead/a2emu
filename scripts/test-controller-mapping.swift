import Cocoa

/// Exercises keyboard output without a controller, emulator, or persistent preference changes.
@main struct ControllerMappingTests {
    static func keys(
        _ mapping: ControllerMapping, _ x: Int32 = 0, _ y: Int32 = 0,
        buttons: UInt32 = 0, physical: UInt32 = 0
    ) -> Set<Int32> {
        return mapping.keyboardKeys(x: x, y: y, buttons: buttons, physicalButtons: physical)
    }

    static func main() throws {
        let legacy = ControllerMapping()
        precondition(keys(legacy) == [])
        precondition(keys(legacy, -32767, -32767) == [86, 91])
        precondition(keys(legacy, buttons: 3) == [55, 58])
        let encodedLegacy = try JSONEncoder().encode(legacy)
        let decodedLegacy = try JSONDecoder().decode(ControllerMapping.self, from: encodedLegacy)
        precondition(decodedLegacy.diagonalKeyCodes == nil && decodedLegacy.keyboardButtonKeyCodes == nil)
        precondition(keys(decodedLegacy, -32767, -32767) == [86, 91])

        var keypad = legacy
        keypad.keyboardMode = true
        keypad.keyCodes = [86, 88, 91, 84, 55, 58]
        keypad.diagonalKeyCodes = [89, 92, 83, 85]
        keypad.keyboardButtonKeyCodes = [87, 58, 82, 76, -1, -1, -1, -1]
        let positions: [(Int32, Int32, Int32)] = [
            (-32767, 0, 86), (32767, 0, 88), (0, -32767, 91), (0, 32767, 84),
            (-32767, -32767, 89), (32767, -32767, 92),
            (-32767, 32767, 83), (32767, 32767, 85),
        ]
        for (x, y, code) in positions { precondition(keys(keypad, x, y) == [code]) }
        precondition(keys(keypad) == [], "Center must not automatically press keypad 5")
        precondition(keys(keypad, physical: 1) == [87], "A controller button must be able to press keypad 5")
        precondition(keys(keypad, -32767, -32767, physical: 1) == [89, 87])
        precondition(keys(keypad, physical: 4) == [82], "Keypad 0 remains assignable")
        precondition(keys(keypad, physical: 8) == [76], "Keypad Enter remains assignable")
        precondition(keys(keypad, physical: 16) == [], "Unassigned buttons must not emit keys")
        precondition(keys(keypad, 16000, -16000) == [], "Threshold boundaries must be stable")
        precondition(
            keys(keypad, 32767, 32767).subtracting(keys(keypad)).contains(85),
            "Centering releases diagonal keys")
        let decoded = try JSONDecoder().decode(ControllerMapping.self, from: JSONEncoder().encode(keypad))
        precondition(keys(decoded, -32767, -32767, physical: 1) == [89, 87])

        let defaults = UserDefaults.standard
        let domain = UserDefaults.argumentDomain
        let original = defaults.volatileDomain(forName: domain)
        defer { defaults.setVolatileDomain(original, forName: domain) }
        func load(_ mapping: ControllerMapping) throws -> ControllerMapping {
            defaults.setVolatileDomain(
                [ControllerMapping.defaultsKey: try JSONEncoder().encode(mapping)], forName: domain)
            return ControllerMapping.load()
        }
        let loaded = try load(keypad)
        precondition(loaded.diagonalKeyCodes == [89, 92, 83, 85])
        var invalid = keypad
        invalid.diagonalKeyCodes = [89]
        let invalidDiagonals = try load(invalid)
        precondition(invalidDiagonals.diagonalKeyCodes == nil)
        invalid = keypad
        invalid.keyboardButtonKeyCodes = [999, -1, -1, -1, -1, -1, -1, -1]
        let invalidButtons = try load(invalid)
        precondition(invalidButtons.keyboardMode == false)
        print(
            "Controller mapping checks passed: eight directions, keypad 5/0/Enter, legacy settings, and validation."
        )
    }
}
