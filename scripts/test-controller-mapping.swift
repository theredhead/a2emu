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
        _ = NSApplication.shared
        var capture = ControllerBindingCapture()
        capture.begin()
        precondition(capture.consume([16]) == nil, "Already held inputs must not bind")
        precondition(capture.consume([]) == nil)
        precondition(capture.consume([8, 16]) == nil, "Ambiguous input must not bind")
        precondition(capture.consume([16]) == 16 && !capture.armed)
        precondition(capture.consume([17]) == nil, "One activation must create only one binding")
        capture.begin()
        capture.cancel()
        precondition(capture.consume([]) == nil && capture.consume([8]) == nil)
        precondition(
            ControllerMapping.activeInputs(x: -32767, y: -32767, physicalButtons: 1 << 9) == [4, 17])
        let keyboardView = KeyboardConfigurationView(frame: NSRect(x: 0, y: 0, width: 884, height: 288))
        let caps = keyboardView.subviews.compactMap { $0 as? NSButton }
        var selected: Int?
        keyboardView.keySelected = { selected = $0 }
        caps.first { $0.accessibilityLabel() == "Space" }!.performClick(nil)
        precondition(selected == 49 && keyboardView.selectedKey == 49)
        precondition(caps.allSatisfy { keyboardView.bounds.contains($0.frame) })
        precondition(caps.count >= 80, "The keyboard includes letters, modifiers, arrows and numpad")
        let returnKey = caps.first { $0.accessibilityLabel() == "Return" }!
        precondition(returnKey.frame.height > returnKey.frame.width)
        precondition(
            returnKey.hitTest(NSPoint(x: returnKey.frame.minX + 10, y: returnKey.frame.maxY - 10)) == nil,
            "The Return notch must not intercept the bracket key")
        precondition(
            returnKey.hitTest(NSPoint(x: returnKey.frame.maxX - 10, y: returnKey.frame.maxY - 10))
                === returnKey)
        let padPlus = caps.first { $0.accessibilityLabel() == "Keypad +" }!
        let padMinus = caps.first { $0.accessibilityLabel() == "Keypad -" }!
        precondition(padPlus.frame.minY > padMinus.frame.minY, "Match the reference keypad operator order")

        if let bitmap = keyboardView.bitmapImageRepForCachingDisplay(in: keyboardView.bounds) {
            keyboardView.cacheDisplay(in: keyboardView.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(
                to: URL(fileURLWithPath: "/private/tmp/a2-keyboard-layout.png"))
        }
        print("PASS full keyboard selection, bounds, neutral gating and one-shot controller binding")
        let preset = ControllerMapping.defaults
        precondition(preset.keyboardStickKeys!.prefix(4) == [86, 88, 91, 84])
        precondition(preset.keyboardDpadAxisOwners == [0, 0])
        precondition(preset.buttonKeys == [55, 58, 58, 55, -1, -1, -1, -1, 53, -1])
        precondition(preset.mouseDirections == [[18], [19], [20], [21]] && preset.mouseButtonInputs == [5])
        precondition(
            preset.independentKeyboardKeys(
                leftX: 0, leftY: 32767, rightX: 32767, rightY: 0,
                dpadX: -32767, dpadY: 0, physicalButtons: (1 << 0) | (1 << 3) | (1 << 8)) == [84, 86, 55, 53])
        print("PASS requested default preset: numpad 4/6/8/2, Apple buttons, Escape and right-stick mouse")
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
        let choices = ControllerMapping.keyChoices
        precondition(Set(choices.map { $0.1 }).count == choices.count, "Keys must have unique codes")
        for letter in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            precondition(choices.contains { $0.0 == String(letter) })
        }
        for digit in 0...9 { precondition(choices.contains { $0.0 == String(digit) }) }
        var keyboard = ControllerMapping()
        keyboard.keyboardMode = true
        keyboard.keyCodes = [0, 2, 13, 1, 55, 58]
        keyboard.keyboardButtonKeyCodes = [49, 53, 36, 48, 59, 56, 18, 41]
        let savedKeyboard = try load(keyboard)
        precondition(savedKeyboard.keyboardMode == true)
        precondition(keys(savedKeyboard, -32767, -32767, physical: 3) == [0, 13, 49, 53])
        precondition(keys(savedKeyboard) == [], "Releasing the controller releases keyboard keys")
        for choice in choices {
            keyboard.keyboardButtonKeyCodes = Array(repeating: choice.1, count: 8)
            let loadedKey = try load(keyboard)
            precondition(keys(loadedKey, physical: 255) == [Int32(choice.1)])
            precondition(keys(loadedKey) == [])
        }
        print("PASS full keyboard choices, saved mappings, simultaneous movement/action keys and release")
        var menuKeys = try load(keypad)
        precondition(
            menuKeys.buttonKeys.count == 10, "Legacy eight-button mappings gain unassigned menu inputs")
        precondition(menuKeys.buttonKeys.suffix(2) == [-1, -1])
        menuKeys.keyboardButtonKeyCodes = menuKeys.buttonKeys
        menuKeys.keyboardButtonKeyCodes![8] = 36
        menuKeys.keyboardButtonKeyCodes![9] = 53
        let savedMenuKeys = try load(menuKeys)
        precondition(keys(savedMenuKeys, physical: 1 << 8) == [36])
        precondition(keys(savedMenuKeys, physical: 1 << 9) == [53])
        precondition(keys(savedMenuKeys, physical: (1 << 8) | (1 << 9)) == [36, 53])
        precondition(keys(savedMenuKeys) == [])
        menuKeys.button0 = 8
        menuKeys.button1 = 9
        let menuJoystick = try load(menuKeys)
        precondition(menuJoystick.button0 == 8 && menuJoystick.button1 == 9)
        print("PASS Menu / Start and Options / Select mapping, persistence and legacy migration")
        var axesMapping = ControllerMapping()
        axesMapping.keyboardLayout = true
        axesMapping.keyboardMode = true
        axesMapping.prepareKeyboardBindings()
        axesMapping.keyboardStickKeys = [0, 2, 13, 1, -1, -1, -1, -1, 123, 124, 126, 125, -1, -1, -1, -1]
        axesMapping.keyboardDpadKeys = Array(repeating: -1, count: 8)
        axesMapping.setDpadOwner(1, axis: 0, enabled: true)
        precondition(
            axesMapping.keyboardDpadAxisOwners == [0, 0], "An axis cannot be claimed from the other stick")
        axesMapping.setDpadOwner(0, axis: 0, enabled: false)
        axesMapping.setDpadOwner(1, axis: 0, enabled: true)
        precondition(
            axesMapping.keyboardDpadAxisOwners == [1, 0], "Horizontal and vertical ownership are independent")
        let savedAxes = try load(axesMapping)
        precondition(savedAxes.keyboardDpadAxisOwners == [1, 0])
        precondition(
            savedAxes.independentKeyboardKeys(
                leftX: -32767, leftY: 0, rightX: 32767, rightY: 0,
                dpadX: -32767, dpadY: -32767, physicalButtons: 0) == [0, 124, 123, 13])
        precondition(
            savedAxes.independentKeyboardKeys(
                leftX: 0, leftY: 0, rightX: 0, rightY: 0,
                dpadX: 0, dpadY: 0, physicalButtons: 0) == [])
        precondition(ControllerMapping.activeInputs(x: 0, y: 32767, physicalButtons: 0) == [3])
        print("PASS independent sticks, diagonal fallback, exclusive per-axis D-pad sharing and persistence")
        let panel = ControllerMappingPanel()
        var liveInputs: Set<Int> = [18]
        panel.show(
            mapping: savedAxes, controllers: { [] }, selectedControllerID: nil,
            preview: { _, _ in (0, 0, 0, [], liveInputs) }, supportedButtons: { _ in Set(0..<10) },
            completion: { _, _ in preconditionFailure("Closing the panel must not save") })
        let window = NSApp.windows.first { $0.title == "Configure Controls" }!
        let root = window.contentView!
        let mode = root.subviews.compactMap { $0 as? NSPopUpButton }.first {
            $0.itemTitles.contains("Apple II Analog Joystick")
        }!
        precondition(mode.itemTitles == ["Apple II Analog Joystick", "Keyboard & Mouse"])

        let fullKeyboard = root.subviews.compactMap { $0 as? KeyboardConfigurationView }.first!
        fullKeyboard.subviews.compactMap { $0 as? NSButton }.first { $0.accessibilityLabel() == "Space" }!
            .performClick(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        func workingMapping() -> ControllerMapping {
            return Mirror(reflecting: panel).children.first { $0.label == "draft" }!.value
                as! ControllerMapping
        }
        precondition(workingMapping().keyboardStickKeys![8] == 123)
        liveInputs = []
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        liveInputs = [18]
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        precondition(workingMapping().keyboardStickKeys![8] == 49)
        precondition(fullKeyboard.selectedKey == -1, "Completed binding must immediately drop the selection")
        precondition(
            !root.subviews.compactMap { $0 as? NSButton }.contains { $0.title.contains("Also bind") })
        precondition(
            root.subviews.compactMap { $0 as? ADBMouseConfigurationView }.first!.frame.minX
                > fullKeyboard.frame.maxX)
        let scaledMouse = root.subviews.compactMap { $0 as? ADBMouseConfigurationView }.first!
        let keyboardScale = fullKeyboard.frame.width / fullKeyboard.bounds.width
        let mouseScale = scaledMouse.frame.width / scaledMouse.bounds.width
        precondition(abs(keyboardScale - mouseScale) < 0.001)
        precondition(
            abs(
                KeyboardConfigurationView.bodyDepth * keyboardScale - ADBMouseConfigurationView.bodyRect
                    .height * mouseScale) < 0.001)
        precondition(
            abs(
                fullKeyboard.frame.minY + 20 * keyboardScale
                    - (scaledMouse.frame.minY + ADBMouseConfigurationView.bodyRect.minY * mouseScale)) < 0.001
        )

        if let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) {
            root.cacheDisplay(in: root.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(
                to: URL(fileURLWithPath: "/private/tmp/a2-keyboard-panel.png"))
        }
        let mouse = root.subviews.compactMap { $0 as? ADBMouseConfigurationView }.first!
        mouse.subviews.compactMap { $0 as? NSButton }.first {
            $0.accessibilityLabel() == "Bind ADB mouse button"
        }!.performClick(nil)
        liveInputs = []
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        liveInputs = [16]
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        precondition(workingMapping().mouseButtonInputs == [8])
        precondition(workingMapping().buttonKeys[8] == -1)
        mouse.subviews.compactMap { $0 as? NSButton }.first {
            $0.accessibilityLabel() == "Bind ADB mouse movement"
        }!.performClick(nil)
        liveInputs = []
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        liveInputs = [18]
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        precondition(workingMapping().mouseMovementSource == 1)
        precondition(workingMapping().keyboardStickKeys!.suffix(8).allSatisfy { $0 == -1 })
        precondition(fullKeyboard.selectedKey == -1)
        precondition(mouse.subviews.compactMap { $0 as? KeypadKey }.allSatisfy { !$0.selected })
        let persistedMouse = try load(workingMapping())
        precondition(persistedMouse.mouseButtonInputs == [8] && persistedMouse.mouseMovementSource == 1)
        precondition(workingMapping().mouseDirections == [[18], [19], [20], [21]])
        let mouseArrows = mouse.subviews.compactMap { $0 as? KeypadKey }.filter { $0.code <= -4 }
        precondition(mouseArrows.count == 4 && mouseArrows.allSatisfy { !$0.assignmentBadges.isEmpty })
        mouseArrows.first { $0.code == -4 }!.performClick(nil)
        liveInputs = []
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        liveInputs = [9]
        RunLoop.main.run(until: Date().addingTimeInterval(0.08))
        precondition(workingMapping().mouseDirections[0].contains(9))
        let vector = workingMapping().mouseVector(axes: [0, 0, 0, 0, 0, 0], physicalButtons: 1 << 1)
        precondition(vector.x == -1 && vector.y == 0)
        let directionSave = try load(workingMapping())
        precondition(directionSave.mouseDirections[0].contains(9))
        print("PASS whole-stick and individual mouse directions, badges, persistence and digital movement")
        window.performClose(nil)
        print("PASS simplified keyboard panel, immediate deselection and mouse beside keyboard")

        let annotationView = KeyboardConfigurationView(frame: NSRect(x: 0, y: 0, width: 884, height: 288))
        var annotated = ControllerMapping()
        annotated.prepareKeyboardBindings()
        annotated.keyboardStickKeys![0] = 49
        annotated.keyboardButtonKeyCodes = [49, -1, -1, -1, -1, -1, -1, -1, -1, -1]
        annotationView.showAssignments(annotated)
        let spaceCap = annotationView.subviews.compactMap { $0 as? KeypadKey }.first { $0.code == 49 }!
        precondition(
            spaceCap.assignmentBadges.map { $0.input }.contains("L←")
                && spaceCap.assignmentBadges.map { $0.input }.contains("A"))
        precondition(spaceCap.toolTip!.contains("D←"), "Mirrored D-pad bindings must also be annotated")
        let loaded = try load(keypad)
        precondition(loaded.diagonalKeyCodes == [89, 92, 83, 85])
        precondition(
            loaded.keyboardLayout == true && loaded.keyboardStickKeys?.prefix(8) == keypad.directionKeys[...])
        precondition(loaded.keyboardDpadAxisOwners == [0, 0], "Legacy keypad D-pad behavior is preserved")
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
