import Foundation

/// Controller bindings and validation; persisted field encodings remain backward compatible.
struct ControllerMapping: Codable {
    var keyboardMode: Bool? = false
    var keyboardLayout: Bool? = nil
    var mouseButtonInputs: [Int]? = nil
    var mouseMovementSource: Int? = nil
    var mouseDirectionInputs: [[Int]]? = nil
    var keyboardStickKeys: [Int]? = nil
    var keyboardDpadKeys: [Int]? = nil

    /// Horizontal and vertical D-pad owners: -1 is independent, 0 left stick, 1 right stick.
    var keyboardDpadAxisOwners: [Int]? = nil
    var keyCodes: [Int]? = nil

    /// Explicit diagonal keys (upper left/right, lower left/right); nil preserves legacy combined presses.
    var diagonalKeyCodes: [Int]? = nil

    /// Keys sent by the physical controller buttons; -1 leaves a button unassigned.
    /// Nil preserves the older two-button mapping stored in `keyCodes`.
    var keyboardButtonKeyCodes: [Int]? = nil

    /// Legacy virtual keys retained when decoding older preferences.
    static let defaultKeyCodes = [86, 88, 91, 87, 55, 58]

    /// Movement source: 0 uses the left stick with D-pad override, 1 the right stick, and 2 the D-pad.
    var movement = 0
    var button0 = 0
    var button1 = 1
    var invertX = false
    var invertY = false
    var deadZone: Float = 0.08

    static let buttonCount = 10
    static let supportedKeyCodes: Set<Int> = [
        0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28,
        29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 53, 55,
        56, 57, 58, 59, 65, 67, 69, 71, 75, 76, 78, 81, 82, 83, 84, 85, 86, 87, 88, 89, 91, 92, 123, 124, 125,
        126,
    ]

    /// Returns saved settings, or defaults if decoding or range validation fails.
    static func decoded(_ data: Data?) -> ControllerMapping {
        guard let data = data,
            var value = try? JSONDecoder().decode(Self.self, from: data),
            (0..<3).contains(value.movement), (0..<buttonCount).contains(value.button0),
            (0..<buttonCount).contains(value.button1),
            value.deadZone.isFinite, (0.08...0.30).contains(value.deadZone),
            value.keyCodes == nil
                || (value.keyCodes!.count == 6
                    && value.keyCodes!.allSatisfy { code in code == -1 || supportedKeyCodes.contains(code)
                    })
        else {
            return Self.defaults
        }

        let validCodes = supportedKeyCodes.union([-1])
        guard
            value.diagonalKeyCodes == nil
                || (value.diagonalKeyCodes!.count == 4
                    && value.diagonalKeyCodes!.allSatisfy({ validCodes.contains($0) })),
            value.keyboardButtonKeyCodes == nil
                || ([8, buttonCount].contains(value.keyboardButtonKeyCodes!.count)
                    && value.keyboardButtonKeyCodes!.allSatisfy({ validCodes.contains($0) }))
        else { return Self.defaults }
        guard
            value.keyboardStickKeys == nil
                || (value.keyboardStickKeys!.count == 16
                    && value.keyboardStickKeys!.allSatisfy({ validCodes.contains($0) })),
            value.keyboardDpadKeys == nil
                || (value.keyboardDpadKeys!.count == 8
                    && value.keyboardDpadKeys!.allSatisfy({ validCodes.contains($0) })),
            value.keyboardDpadAxisOwners == nil
                || (value.keyboardDpadAxisOwners!.count == 2
                    && value.keyboardDpadAxisOwners!.allSatisfy({ (-1...1).contains($0) }))
        else { return Self.defaults }
        if value.keyboardMode == true && value.keyboardLayout != true {
            value.prepareKeyboardBindings()
            value.keyboardLayout = true
        }
        guard
            value.mouseButtonInputs == nil
                || value.mouseButtonInputs!.allSatisfy({ (0..<buttonCount).contains($0) }),
            value.mouseMovementSource == nil || (0..<3).contains(value.mouseMovementSource!)
        else { return Self.defaults }
        guard
            value.mouseDirectionInputs == nil
                || (value.mouseDirectionInputs!.count == 4
                    && value.mouseDirectionInputs!.allSatisfy({ $0.allSatisfy { (0..<34).contains($0) } }))
        else { return Self.defaults }
        return value
    }

    /// New-player bindings; decoding older preferences continues to use their original defaults.
    static var defaults: ControllerMapping {
        var mapping = ControllerMapping()
        mapping.keyboardLayout = true
        mapping.keyCodes = [86, 88, 91, 84, 55, 58]
        mapping.keyboardStickKeys = [86, 88, 91, 84, -1, -1, -1, -1] + Array(repeating: -1, count: 8)
        mapping.keyboardDpadKeys = Array(repeating: -1, count: 8)
        mapping.keyboardDpadAxisOwners = [0, 0]
        mapping.keyboardButtonKeyCodes = [55, 58, 58, 55, -1, -1, -1, -1, 53, -1]
        mapping.mouseMovementSource = 1
        mapping.mouseButtonInputs = [5]
        return mapping
    }

    /// Explicit mouse directions override the older whole-stick setting without losing its bindings.
    var mouseDirections: [[Int]] {
        if let directions = mouseDirectionInputs { return directions }
        guard let source = mouseMovementSource else { return Array(repeating: [], count: 4) }

        let offset = [0, 18, 26][source]
        return (0..<4).map { [offset + $0] }
    }

    mutating func removeMouseInput(_ input: Int) {
        mouseDirectionInputs = mouseDirections.map { $0.filter { $0 != input } }
        mouseMovementSource = nil
    }

    /// Computes proportional stick movement and digital button movement using the same direction bindings.
    func mouseVector(axes: [Int32], physicalButtons: UInt32) -> (x: Double, y: Double) {
        func strength(_ input: Int) -> Double {
            if (8..<18).contains(input) { return physicalButtons & (1 << (input - 8)) != 0 ? 1 : 0 }

            let source = input < 8 ? 0 : (input < 26 ? 1 : 2)
            let direction = input - [0, 18, 26][source]
            let x = Double(axes[source * 2]) / 32767
            let y = Double(axes[source * 2 + 1]) / 32767
            let cardinal = [max(0, -x), max(0, x), max(0, -y), max(0, y)]
            if direction < 4 { return cardinal[direction] }
            return min(cardinal[(direction - 4) % 2], cardinal[direction < 6 ? 2 : 3])
        }

        let amounts = mouseDirections.map { $0.map { strength($0) }.max() ?? 0 }
        return (amounts[1] - amounts[0], amounts[3] - amounts[2])
    }

    /// Effective keyboard assignments, including legacy defaults for existing players.
    var directionKeys: [Int] {
        Array((keyCodes ?? Self.defaultKeyCodes).prefix(4)) + (diagonalKeyCodes ?? [-1, -1, -1, -1])
    }

    var buttonKeys: [Int] {
        if let keys = keyboardButtonKeyCodes {
            return keys + Array(repeating: -1, count: Self.buttonCount - keys.count)
        }

        let keys = keyCodes ?? Self.defaultKeyCodes
        var result = Array(repeating: -1, count: Self.buttonCount)
        result[button0] = keys[4]
        result[button1] = keys[5]
        return result
    }

    /// Initializes independent keyboard controls from the existing movement-source setting once.
    mutating func prepareKeyboardBindings() {
        if keyboardStickKeys == nil {
            keyboardStickKeys = Array(repeating: -1, count: 16)
            if movement != 2 {
                keyboardStickKeys!.replaceSubrange(
                    (movement == 1 ? 8 : 0)..<(movement == 1 ? 16 : 8), with: directionKeys)
            }
        }
        if keyboardDpadKeys == nil {
            keyboardDpadKeys = movement == 2 ? directionKeys : Array(repeating: -1, count: 8)
        }
        if keyboardDpadAxisOwners == nil { keyboardDpadAxisOwners = movement == 0 ? [0, 0] : [-1, -1] }
    }

    /// Left-stick directions, physical buttons, right-stick directions, then independent D-pad directions.
    var keyboardInputKeys: [Int] {
        let sticks = keyboardStickKeys ?? directionKeys + Array(repeating: -1, count: 8)
        return Array(sticks.prefix(8)) + buttonKeys + Array(sticks.suffix(8))
            + (keyboardDpadKeys ?? Array(repeating: -1, count: 8))
    }

    /// A D-pad axis can mirror only one stick; it must be released before another stick can claim it.
    mutating func setDpadOwner(_ stick: Int, axis: Int, enabled: Bool) {
        prepareKeyboardBindings()
        let owner = keyboardDpadAxisOwners![axis]
        if enabled && (owner == -1 || owner == stick) { keyboardDpadAxisOwners![axis] = stick }
        if !enabled && owner == stick { keyboardDpadAxisOwners![axis] = -1 }
    }

    func independentKeyboardKeys(
        leftX: Int32, leftY: Int32, rightX: Int32, rightY: Int32,
        dpadX: Int32, dpadY: Int32, physicalButtons: UInt32
    ) -> Set<Int32> {
        let sticks = keyboardStickKeys ?? Array(repeating: -1, count: 16)
        let dpad = keyboardDpadKeys ?? Array(repeating: -1, count: 8)
        let owners = keyboardDpadAxisOwners ?? [-1, -1]
        var result = Set<Int32>()

        func press(_ x: Int32, _ y: Int32, _ keys: [Int]) {
            let horizontal = x < -16000 ? 0 : (x > 16000 ? 1 : nil)
            let vertical = y < -16000 ? 2 : (y > 16000 ? 3 : nil)
            if let horizontal = horizontal, let vertical = vertical {
                let diagonal = keys[4 + (vertical == 3 ? 2 : 0) + horizontal]
                if diagonal >= 0 {
                    result.insert(Int32(diagonal))
                    return
                }
            }
            if let horizontal = horizontal, keys[horizontal] >= 0 { result.insert(Int32(keys[horizontal])) }
            if let vertical = vertical, keys[vertical] >= 0 { result.insert(Int32(keys[vertical])) }
        }

        let left = Array(sticks.prefix(8))
        let right = Array(sticks.suffix(8))
        press(leftX, leftY, left)
        press(rightX, rightY, right)
        let horizontal = owners[0] == 0 ? left : (owners[0] == 1 ? right : dpad)
        let vertical = owners[1] == 0 ? left : (owners[1] == 1 ? right : dpad)
        if owners[0] == owners[1] {
            press(dpadX, dpadY, horizontal)
        } else {
            press(dpadX, 0, horizontal)
            press(0, dpadY, vertical)
        }
        for index in buttonKeys.indices where physicalButtons & (1 << index) != 0 && buttonKeys[index] >= 0 {
            result.insert(Int32(buttonKeys[index]))
        }
        return result
    }

    /// Direction indices match the editor; diagonals are a single input rather than two cardinals.
    static func activeInputs(x: Int32, y: Int32, physicalButtons: UInt32) -> Set<Int> {
        var inputs = Set<Int>()
        let horizontal = x < -16000 ? 0 : (x > 16000 ? 1 : nil)
        let vertical = y < -16000 ? 2 : (y > 16000 ? 3 : nil)
        if let horizontal = horizontal, let vertical = vertical {
            inputs.insert(4 + (vertical == 3 ? 2 : 0) + horizontal)
        } else {
            if let horizontal = horizontal { inputs.insert(horizontal) }
            if let vertical = vertical { inputs.insert(vertical) }
        }
        for index in (0..<buttonCount) where physicalButtons & (1 << index) != 0 {
            inputs.insert(8 + index)
        }
        return inputs
    }

    /// Converts controller state to keys; explicit diagonals replace combined cardinal presses.
    func keyboardKeys(x: Int32, y: Int32, buttons: UInt32, physicalButtons: UInt32) -> Set<Int32> {
        var result = Set<Int32>()
        let horizontal = x < -16000 ? 0 : (x > 16000 ? 1 : nil)
        let vertical = y < -16000 ? 2 : (y > 16000 ? 3 : nil)
        let keys = keyCodes ?? Self.defaultKeyCodes
        if let horizontal = horizontal, let vertical = vertical, let diagonals = diagonalKeyCodes {
            let index = (vertical == 3 ? 2 : 0) + horizontal
            if diagonals[index] >= 0 { result.insert(Int32(diagonals[index])) }
        } else {
            if let horizontal = horizontal, keys[horizontal] >= 0 { result.insert(Int32(keys[horizontal])) }
            if let vertical = vertical, keys[vertical] >= 0 { result.insert(Int32(keys[vertical])) }
        }
        if let assigned = keyboardButtonKeyCodes {
            for index in assigned.indices where physicalButtons & (1 << index) != 0 && assigned[index] >= 0 {
                result.insert(Int32(assigned[index]))
            }
        } else {
            if buttons & 1 != 0, keys[4] >= 0 { result.insert(Int32(keys[4])) }
            if buttons & 2 != 0, keys[5] >= 0 { result.insert(Int32(keys[5])) }
        }
        return result
    }
}
