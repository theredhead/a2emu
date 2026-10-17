import Cocoa
import GameController

private let commonIntl = CommonIntl()
private let controllerConfigurationIntl = ControllerConfigurationIntl()

/// Per-player controller preferences persisted in user defaults.
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
    static let keyChoices: [(String, Int)] = [
        (controllerConfigurationIntl.keypad7, 89), (controllerConfigurationIntl.keypad9, 92),
        (controllerConfigurationIntl.keypad1, 83), (controllerConfigurationIntl.keypad3, 85),
        (controllerConfigurationIntl.keypad0, 82), (controllerConfigurationIntl.keypadDecimal, 65),
        (controllerConfigurationIntl.keypadEnter, 76), (controllerConfigurationIntl.keypadClear, 71),
        (controllerConfigurationIntl.keypadEquals, 81), (controllerConfigurationIntl.keypadDivide, 75),
        (controllerConfigurationIntl.keypadMultiply, 67), (controllerConfigurationIntl.keypadMinus, 78),
        (controllerConfigurationIntl.keypadPlus, 69),
        (controllerConfigurationIntl.keypad4, 86), (controllerConfigurationIntl.keypad6, 88),
        (controllerConfigurationIntl.keypad8, 91), (controllerConfigurationIntl.keypad5, 87),
        (controllerConfigurationIntl.keypad2, 84),
        (controllerConfigurationIntl.commandOpenApple, 55),
        (controllerConfigurationIntl.optionClosedApple, 58), (controllerConfigurationIntl.leftArrow, 123),
        (controllerConfigurationIntl.rightArrow, 124), (controllerConfigurationIntl.upArrow, 126),
        (controllerConfigurationIntl.downArrow, 125), (controllerConfigurationIntl.space, 49),
        (controllerConfigurationIntl.returnLabel, 36), ("A", 0),
        ("B", 11), ("C", 8), ("D", 2), ("E", 14), ("F", 3), ("G", 5), ("H", 4),
        ("I", 34), ("J", 38), ("K", 40), ("L", 37), ("M", 46), ("N", 45), ("O", 31),
        ("P", 35), ("Q", 12), ("R", 15), ("S", 1), ("T", 17), ("U", 32), ("V", 9),
        ("W", 13), ("X", 7), ("Y", 16), ("Z", 6),
        ("0", 29), ("1", 18), ("2", 19), ("3", 20), ("4", 21), ("5", 23), ("6", 22),
        ("7", 26), ("8", 28), ("9", 25),
        ("-", 27), ("=", 24), ("[", 33), ("]", 30), (";", 41), ("'", 39),
        (",", 43), (".", 47), ("/", 44), (controllerConfigurationIntl.backslash, 42),
        (controllerConfigurationIntl.backtick, 50),
        (controllerConfigurationIntl.capsLock, 57), (controllerConfigurationIntl.escape, 53),
        (controllerConfigurationIntl.tab, 48), (controllerConfigurationIntl.delete, 51),
        (controllerConfigurationIntl.shift, 56), (controllerConfigurationIntl.control, 59),
    ]

    /// Movement source: 0 uses the left stick with D-pad override, 1 the right stick, and 2 the D-pad.
    var movement = 0
    var button0 = 0
    var button1 = 1
    var invertX = false
    var invertY = false
    var deadZone: Float = 0.08
    static let buttonNames = [
        "A", "B", "X", "Y", controllerConfigurationIntl.leftShoulder,
        controllerConfigurationIntl.rightShoulder, controllerConfigurationIntl.leftTrigger,
        controllerConfigurationIntl.rightTrigger,
        controllerConfigurationIntl.menuStart, controllerConfigurationIntl.optionsSelect,
    ]
    static let movementNames = [
        controllerConfigurationIntl.leftAnalogStickDPad, controllerConfigurationIntl.rightAnalogStick,
        controllerConfigurationIntl.dPad,
    ]
    static let defaultsKey = "AppleIIControllerMapping"

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

    /// Returns saved settings, or defaults if decoding or range validation fails.
    static func load() -> ControllerMapping {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
            var value = try? JSONDecoder().decode(Self.self, from: data),
            (0..<3).contains(value.movement), buttonNames.indices.contains(value.button0),
            buttonNames.indices.contains(value.button1),
            value.deadZone.isFinite, (0.08...0.30).contains(value.deadZone),
            value.keyCodes == nil
                || (value.keyCodes!.count == 6
                    && value.keyCodes!.allSatisfy { code in code == -1 || keyChoices.contains { $0.1 == code }
                    })
        else {
            return Self.defaults
        }
        let validCodes = Set(keyChoices.map { $0.1 } + [-1])
        guard
            value.diagonalKeyCodes == nil
                || (value.diagonalKeyCodes!.count == 4
                    && value.diagonalKeyCodes!.allSatisfy({ validCodes.contains($0) })),
            value.keyboardButtonKeyCodes == nil
                || ([8, buttonNames.count].contains(value.keyboardButtonKeyCodes!.count)
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
                || value.mouseButtonInputs!.allSatisfy({ buttonNames.indices.contains($0) }),
            value.mouseMovementSource == nil || (0..<3).contains(value.mouseMovementSource!)
        else { return Self.defaults }
        guard
            value.mouseDirectionInputs == nil
                || (value.mouseDirectionInputs!.count == 4
                    && value.mouseDirectionInputs!.allSatisfy({ $0.allSatisfy { (0..<34).contains($0) } }))
        else { return Self.defaults }
        return value
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
            return keys + Array(repeating: -1, count: Self.buttonNames.count - keys.count)
        }
        let keys = keyCodes ?? Self.defaultKeyCodes
        var result = Array(repeating: -1, count: Self.buttonNames.count)
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
        for index in buttonNames.indices where physicalButtons & (1 << index) != 0 {
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

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    func button(_ index: Int, on pad: GCExtendedGamepad) -> GCControllerButtonInput? {
        [
            pad.buttonA, pad.buttonB, pad.buttonX, pad.buttonY, pad.leftShoulder, pad.rightShoulder,
            pad.leftTrigger, pad.rightTrigger, pad.buttonMenu, pad.buttonOptions,
        ][index]
    }
}

/// A controller connection, identified independently of its potentially duplicated display name.
struct ControllerChoice: Equatable {
    let id: String
    let name: String
}

/// Edits a working copy; previews never send input to the emulated machine.
final class ControllerMappingPanel: NSObject, NSWindowDelegate {
    var didClose: (() -> Void)?
    private var window: NSWindow!
    private var originalFrames: [(NSView, NSRect)] = []
    private var draft = ControllerMapping()
    private let joystick = JoystickConfigurationView(frame: NSRect(x: 28, y: 128, width: 440, height: 440))
    private static let peripheralScale: CGFloat = 690 / 884
    private let fullKeyboard = KeyboardConfigurationView(
        frame: NSRect(x: 28, y: 295, width: 690, height: 288 * ControllerMappingPanel.peripheralScale))
    private let adbMouse = ADBMouseConfigurationView(
        frame: NSRect(
            x: 724,
            y: 295 + (20 - ADBMouseConfigurationView.bodyRect.minY) * ControllerMappingPanel.peripheralScale,
            width: 240 * ControllerMappingPanel.peripheralScale,
            height: 340 * ControllerMappingPanel.peripheralScale))
    private let bindingStatus = NSTextField(wrappingLabelWithString: "")
    private let clearBinding = NSButton(
        title: controllerConfigurationIntl.clearKeyBindings, target: nil, action: nil)
    private var bindingCapture = ControllerBindingCapture()
    private let targetMode = NSPopUpButton(frame: .zero)
    private let selectionTitle = NSTextField(labelWithString: "")
    private let explanation = NSTextField(wrappingLabelWithString: "")
    private let sourceLabel = NSTextField(labelWithString: "")
    private let source = NSPopUpButton(frame: .zero)
    private let movementLabel = NSTextField(labelWithString: controllerConfigurationIntl.controllerMovement)
    private let movement = NSPopUpButton(frame: .zero)
    private let invertX = NSButton(
        checkboxWithTitle: controllerConfigurationIntl.invertHorizontal, target: nil, action: nil)
    private let invertY = NSButton(
        checkboxWithTitle: controllerConfigurationIntl.invertVertical, target: nil, action: nil)
    private let deadZone = NSSlider(value: 8, minValue: 8, maxValue: 30, target: nil, action: nil)
    private let deadZoneLabel = NSTextField(labelWithString: controllerConfigurationIntl.initialDeadZone)
    private let footerHint = NSTextField(
        labelWithString: controllerConfigurationIntl.previewHint)
    private let subtitle = NSTextField(labelWithString: "")
    private let heading = NSTextField(labelWithString: "")
    private let device = NSPopUpButton(frame: .zero)
    private let previewStatus = NSTextField(labelWithString: "")
    private var supportedButtons: ((String?) -> Set<Int>?)?
    private var controllerChoices: (() -> [ControllerChoice])?
    private var lastChoices: [ControllerChoice] = []
    private var draftControllerID: String?
    private var selectedControllerName = controllerConfigurationIntl.controller
    private let directions = [
        controllerConfigurationIntl.left, controllerConfigurationIntl.right, controllerConfigurationIntl.up,
        controllerConfigurationIntl.down, controllerConfigurationIntl.upperLeft,
        controllerConfigurationIntl.upperRight, controllerConfigurationIntl.lowerLeft,
        controllerConfigurationIntl.lowerRight,
    ]
    private var selectedKey = 87
    private var previewTimer: Timer?
    private var preview:
        (
            (ControllerMapping, String?) -> (
                buttons: UInt32, x: Int32, y: Int32, keys: Set<Int32>, inputs: Set<Int>
            )?
        )?
    private var completion: ((ControllerMapping, String?) -> Void)?

    func show(
        mapping: ControllerMapping, controllers: @escaping () -> [ControllerChoice],
        selectedControllerID: String?,
        preview:
            @escaping (ControllerMapping, String?) -> (
                buttons: UInt32, x: Int32, y: Int32, keys: Set<Int32>, inputs: Set<Int>
            )?,
        supportedButtons: ((String?) -> Set<Int>?)? = nil,
        completion: @escaping (ControllerMapping, String?) -> Void
    ) {
        if window == nil { build() }
        self.supportedButtons = supportedButtons
        self.completion = completion
        self.preview = preview
        self.controllerChoices = controllers
        draftControllerID = selectedControllerID
        draft = mapping
        if draft.keyboardMode == true {
            draft.prepareKeyboardBindings()
            draft.keyboardLayout = true
        }
        refreshControllers(force: true)
        refresh()
        window.center()
        window.makeKeyAndOrderFront(nil)
        previewTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.updatePreview() }
        RunLoop.main.add(timer, forMode: .commonModes)
        previewTimer = timer
        updatePreview()
    }

    private func build() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 940, height: 720),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = controllerConfigurationIntl.configureControls
        window.isReleasedWhenClosed = false
        window.delegate = self
        let root = window.contentView!
        heading.font = .systemFont(ofSize: 26, weight: .semibold)
        heading.frame = NSRect(x: 28, y: 662, width: 880, height: 34)
        root.addSubview(heading)

        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 28, y: 634, width: 880, height: 24)
        root.addSubview(subtitle)
        let controllerLabel = NSTextField(labelWithString: controllerConfigurationIntl.controller)
        controllerLabel.frame = NSRect(x: 28, y: 604, width: 80, height: 22)
        controllerLabel.textColor = .secondaryLabelColor
        root.addSubview(controllerLabel)
        device.frame = NSRect(x: 112, y: 600, width: 346, height: 28)
        device.target = self
        device.action = #selector(selectController(_:))
        device.setAccessibilityLabel(controllerConfigurationIntl.activeGameController)
        device.toolTip =
            controllerConfigurationIntl.controllerSelectionHint
        root.addSubview(device)
        previewStatus.frame = NSRect(x: 500, y: 604, width: 410, height: 22)
        previewStatus.font = .systemFont(ofSize: 12)
        previewStatus.textColor = .secondaryLabelColor
        root.addSubview(previewStatus)
        for y in [590, 64] {
            let line = NSBox(frame: NSRect(x: 28, y: y, width: 884, height: 1))
            line.boxType = .separator
            root.addSubview(line)
        }
        root.addSubview(joystick)
        fullKeyboard.bounds = NSRect(x: 0, y: 0, width: 884, height: 288)
        root.addSubview(fullKeyboard)
        adbMouse.bounds = NSRect(x: 0, y: 0, width: 240, height: 340)
        root.addSubview(adbMouse)
        adbMouse.controlSelected = { [weak self] control in
            self?.selectedKey = control
            self?.bindingCapture.begin()
            self?.refreshEditor()
        }
        fullKeyboard.keySelected = { [weak self] code in
            self?.selectedKey = code
            self?.bindingCapture.begin()
            self?.refreshEditor()
        }
        bindingStatus.frame = NSRect(x: 500, y: 146, width: 412, height: 44)
        root.addSubview(bindingStatus)
        clearBinding.frame = NSRect(x: 28, y: 152, width: 180, height: 32)
        clearBinding.bezelStyle = .rounded
        clearBinding.target = self
        clearBinding.action = #selector(clearSelectedBinding(_:))
        root.addSubview(clearBinding)
        joystick.selectionChanged = { [weak self] _ in self?.refreshEditor() }
        targetMode.frame = NSRect(x: 28, y: 552, width: 430, height: 28)
        targetMode.addItems(withTitles: [
            controllerConfigurationIntl.appleIiAnalogJoystick, controllerConfigurationIntl.keyboardMouse,
        ])
        targetMode.target = self
        targetMode.action = #selector(changeMode(_:))
        root.addSubview(targetMode)
        selectionTitle.font = .systemFont(ofSize: 23, weight: .semibold)
        selectionTitle.frame = NSRect(x: 500, y: 538, width: 400, height: 32)
        root.addSubview(selectionTitle)
        explanation.textColor = .secondaryLabelColor
        explanation.frame = NSRect(x: 500, y: 482, width: 410, height: 48)
        root.addSubview(explanation)
        sourceLabel.frame = NSRect(x: 500, y: 444, width: 400, height: 22)
        root.addSubview(sourceLabel)
        source.frame = NSRect(x: 500, y: 406, width: 400, height: 28)
        source.target = self
        source.action = #selector(changeSource(_:))
        root.addSubview(source)
        movementLabel.frame = NSRect(x: 500, y: 228, width: 400, height: 22)
        root.addSubview(movementLabel)
        movement.frame = NSRect(x: 500, y: 192, width: 400, height: 28)
        movement.addItems(withTitles: ControllerMapping.movementNames)
        movement.target = self
        movement.action = #selector(changeMovement(_:))
        root.addSubview(movement)
        for (button, x) in [(invertX, 500), (invertY, 708)] {
            button.frame = NSRect(x: x, y: 148, width: 200, height: 24)
            button.target = self
            button.action = #selector(changeAxes(_:))
            root.addSubview(button)
        }
        deadZoneLabel.frame = NSRect(x: 500, y: 108, width: 150, height: 24)
        root.addSubview(deadZoneLabel)
        deadZone.frame = NSRect(x: 654, y: 108, width: 246, height: 24)
        deadZone.target = self
        deadZone.action = #selector(changeDeadZone(_:))
        deadZone.setAccessibilityLabel(controllerConfigurationIntl.controllerDeadZone)
        root.addSubview(deadZone)
        footerHint.font = .systemFont(ofSize: 11)
        footerHint.textColor = .secondaryLabelColor
        footerHint.frame = NSRect(x: 28, y: 78, width: 440, height: 20)
        root.addSubview(footerHint)
        let reset = NSButton(
            title: controllerConfigurationIntl.restoreDefaults, target: self, action: #selector(reset(_:)))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 28, y: 18, width: 154, height: 32)
        root.addSubview(reset)
        let cancel = NSButton(title: commonIntl.cancel, target: self, action: #selector(cancel(_:)))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        cancel.frame = NSRect(x: 688, y: 18, width: 100, height: 32)
        root.addSubview(cancel)
        let save = NSButton(title: commonIntl.save, target: self, action: #selector(save(_:)))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.frame = NSRect(x: 800, y: 18, width: 112, height: 32)
        root.addSubview(save)
        originalFrames = root.subviews.map { ($0, $0.frame) }
    }

    private func refresh() {
        targetMode.selectItem(at: draft.keyboardMode == true ? 1 : 0)
        movement.selectItem(at: draft.movement)
        invertX.state = draft.invertX ? .on : .off
        invertY.state = draft.invertY ? .on : .off
        deadZone.doubleValue = Double(draft.deadZone * 100)
        deadZoneLabel.stringValue = controllerConfigurationIntl.deadZone(
            percent: Int(deadZone.doubleValue.rounded()))
        joystick.showAssignments(draft)
        refreshEditor()
    }

    private func refreshEditor() {
        let keyboardBindings = draft.keyboardMode == true && draft.keyboardLayout == true
        let contentHeight: CGFloat = keyboardBindings ? 600 : 720
        if window.contentView!.frame.height != contentHeight {
            let top = window.frame.maxY
            window.setContentSize(NSSize(width: 940, height: contentHeight))
            window.setFrameOrigin(NSPoint(x: window.frame.minX, y: top - window.frame.height))
        }
        for (view, original) in originalFrames {
            var frame = original
            if keyboardBindings && frame.minY > 250 { frame.origin.y -= 120 }
            view.frame = frame
        }
        clearBinding.frame.origin.y = 96
        selectionTitle.font = .systemFont(ofSize: keyboardBindings ? 17 : 23, weight: .semibold)
        footerHint.isHidden = keyboardBindings
        bindingStatus.isHidden = !keyboardBindings
        clearBinding.isHidden = !keyboardBindings
        fullKeyboard.isHidden = !keyboardBindings
        adbMouse.isHidden = !keyboardBindings
        subtitle.stringValue =
            keyboardBindings
            ? controllerConfigurationIntl.keyboardInstructions
            : controllerConfigurationIntl.joystickInstructions
        heading.stringValue =
            keyboardBindings
            ? controllerConfigurationIntl.keyboardMouseSettings : controllerConfigurationIntl.joystickSettings
        joystick.isHidden = keyboardBindings
        source.isHidden = keyboardBindings || joystick.selectedControl.isDirection
        sourceLabel.isHidden = source.isHidden
        for view in [movementLabel, movement, invertX, invertY, deadZoneLabel, deadZone] {
            view.isHidden = keyboardBindings
        }
        let movementY: CGFloat =
            keyboardBindings ? 192 : (joystick.selectedControl.isDirection ? 406 : 288)
        movement.frame.origin.y = movementY
        movementLabel.frame.origin.y = movementY + 36
        let axesY: CGFloat = keyboardBindings ? 148 : movementY - 56
        invertX.frame.origin.y = axesY
        invertY.frame.origin.y = axesY
        deadZoneLabel.frame.origin.y = axesY - 40
        deadZone.frame.origin.y = axesY - 40
        selectionTitle.frame =
            keyboardBindings
            ? NSRect(x: 235, y: 96, width: 235, height: 32) : NSRect(x: 500, y: 538, width: 400, height: 32)
        explanation.isHidden = keyboardBindings
        if keyboardBindings {
            let name =
                selectedKey <= -4
                ? [
                    controllerConfigurationIntl.mouseLeft, controllerConfigurationIntl.mouseRight,
                    controllerConfigurationIntl.mouseUp, controllerConfigurationIntl.mouseDown,
                ][-selectedKey - 4]
                : selectedKey == -2
                    ? controllerConfigurationIntl.mouseButton
                    : (selectedKey == -3
                        ? controllerConfigurationIntl.mouseMovement
                        : (ControllerMapping.keyChoices.first { $0.1 == selectedKey }?.0
                            ?? controllerConfigurationIntl.key))
            selectionTitle.stringValue = name
            let titleHeight =
                selectionTitle.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: 235, height: 32)).height
                ?? 22
            selectionTitle.frame = NSRect(x: 235, y: 112 - titleHeight / 2, width: 235, height: titleHeight)
            let inputs = draft.keyboardInputKeys
            let names =
                directions.map { controllerConfigurationIntl.leftStick(direction: $0.lowercased()) }
                + ControllerMapping.buttonNames
                + directions.map { controllerConfigurationIntl.rightStick(direction: $0.lowercased()) }
                + directions.map { controllerConfigurationIntl.dPadDirection(direction: $0.lowercased()) }
            var assigned = inputs.indices.filter { inputs[$0] == selectedKey }.map { names[$0] }
            if selectedKey == -2 {
                assigned = (draft.mouseButtonInputs ?? []).map { ControllerMapping.buttonNames[$0] }
            }
            if selectedKey <= -4 { assigned = draft.mouseDirections[-selectedKey - 4].map { names[$0] } }
            if selectedKey == -3 {
                assigned =
                    Array(Set(draft.mouseDirections.flatMap { $0 })).sorted().map { names[$0] }
            }
            bindingStatus.stringValue =
                bindingCapture.armed
                ? controllerConfigurationIntl.keyBindingHint(name: name)
                : (assigned.isEmpty
                    ? controllerConfigurationIntl.idleBindingHint
                    : controllerConfigurationIntl.boundTo(bindings: assigned.joined(separator: ", ")))
            if bindingCapture.armed && selectedKey == -2 {
                bindingStatus.stringValue =
                    controllerConfigurationIntl.mouseButtonBindingHint
            }
            if bindingCapture.armed && selectedKey == -3 {
                bindingStatus.stringValue =
                    controllerConfigurationIntl.mouseMovementBindingHint
            }
            let statusBounds = NSRect(x: 0, y: 0, width: 412, height: 44)
            let statusHeight = min(44, bindingStatus.cell?.cellSize(forBounds: statusBounds).height ?? 18)
            bindingStatus.frame = NSRect(x: 500, y: 112 - statusHeight / 2, width: 412, height: statusHeight)
            bindingStatus.toolTip = bindingStatus.stringValue
            fullKeyboard.selectedKey = bindingCapture.armed ? selectedKey : -1
            adbMouse.showAssignments(draft, selectedControl: bindingCapture.armed ? selectedKey : nil)
            clearBinding.title =
                selectedKey < 0
                ? controllerConfigurationIntl.clearMouseBinding : controllerConfigurationIntl.clearKeyBindings
            fullKeyboard.showAssignments(draft)
        } else {
            let control = joystick.selectedControl
            selectionTitle.stringValue =
                control.isDirection
                ? controllerConfigurationIntl.direction(control: control.label)
                : controllerConfigurationIntl.joystick(control: control.label.lowercased())
            explanation.stringValue =
                control.isDirection
                ? controllerConfigurationIntl.directionInstructions
                : controllerConfigurationIntl.buttonInstructions
            if !control.isDirection {
                sourceLabel.stringValue = controllerConfigurationIntl.controllerButton
                source.removeAllItems()
                source.menu?.autoenablesItems = false
                source.addItems(withTitles: ControllerMapping.buttonNames)
                source.selectItem(at: control == .button0 ? draft.button0 : draft.button1)
                source.setAccessibilityLabel(
                    controllerConfigurationIntl.controllerAssignment(control: control.label))
            }
        }
    }

    @objc private func changeMode(_ sender: Any?) {
        bindingCapture.cancel()
        draft.keyboardLayout = targetMode.indexOfSelectedItem == 1
        draft.keyboardMode = targetMode.indexOfSelectedItem != 0
        if draft.keyboardMode == true {
            draft.prepareKeyboardBindings()
            draft.keyboardLayout = true
        }
        refresh()
    }

    @objc private func clearSelectedBinding(_ sender: Any?) {
        bindingCapture.cancel()
        if selectedKey == -2 {
            draft.mouseButtonInputs = []
        } else if selectedKey == -3 {
            draft.mouseMovementSource = nil
            draft.mouseDirectionInputs = nil
        } else if selectedKey <= -4 {
            var directions = draft.mouseDirections
            directions[-selectedKey - 4] = []
            draft.mouseDirectionInputs = directions
            draft.mouseMovementSource = nil
        } else {
            let inputs = draft.keyboardInputKeys
            for index in inputs.indices where inputs[index] == selectedKey { bindInput(index, to: -1) }
        }
        refreshEditor()
    }

    private func bindInput(_ input: Int, to code: Int) {
        draft.prepareKeyboardBindings()
        if input < 8 {
            draft.keyboardStickKeys![input] = code
        } else if input < 18 {
            var keys = draft.buttonKeys
            keys[input - 8] = code
            draft.keyboardButtonKeyCodes = keys
        } else if input < 26 {
            draft.keyboardStickKeys![input - 18 + 8] = code
        } else {
            draft.keyboardDpadKeys![input - 26] = code
            let direction = input - 26
            if direction < 2 || direction >= 4 { draft.keyboardDpadAxisOwners![0] = -1 }
            if direction >= 2 { draft.keyboardDpadAxisOwners![1] = -1 }
        }
    }

    @objc private func changeSource(_ sender: Any?) {
        if joystick.selectedControl == .button0 {
            draft.button0 = source.indexOfSelectedItem
        } else {
            draft.button1 = source.indexOfSelectedItem
        }
        joystick.showAssignments(draft)
    }

    @objc private func changeMovement(_ sender: Any?) { draft.movement = movement.indexOfSelectedItem }

    @objc private func changeAxes(_ sender: Any?) {
        draft.invertX = invertX.state == .on
        draft.invertY = invertY.state == .on
    }

    @objc private func changeDeadZone(_ sender: Any?) {
        draft.deadZone = Float(deadZone.doubleValue.rounded()) / 100
        deadZoneLabel.stringValue = controllerConfigurationIntl.deadZone(
            percent: Int(deadZone.doubleValue.rounded()))
    }

    @objc private func reset(_ sender: Any?) {
        let keyboard = draft.keyboardMode == true
        bindingCapture.cancel()
        draft = ControllerMapping.defaults
        draft.keyboardMode = keyboard
        refresh()
    }

    private func refreshControllers(force: Bool = false) {
        let choices = controllerChoices?() ?? []
        if let selected = choices.first(where: { $0.id == draftControllerID }) {
            selectedControllerName = selected.name
        }
        guard force || choices != lastChoices else { return }
        lastChoices = choices
        device.removeAllItems()
        device.addItem(withTitle: controllerConfigurationIntl.automatic)
        device.lastItem?.representedObject = ""
        for choice in choices {
            device.addItem(withTitle: choice.name)
            device.lastItem?.representedObject = choice.id
        }
        if let identifier = draftControllerID, !choices.contains(where: { $0.id == identifier }) {
            device.addItem(withTitle: controllerConfigurationIntl.disconnected(name: selectedControllerName))
            device.lastItem?.representedObject = identifier
            device.lastItem?.isEnabled = false
        }
        let selectedIndex =
            device.itemArray.firstIndex {
                ($0.representedObject as? String) == (draftControllerID ?? "")
            } ?? 0
        device.selectItem(at: selectedIndex)
        device.isEnabled = device.numberOfItems > 1
    }

    @objc private func selectController(_ sender: Any?) {
        let identifier = device.selectedItem?.representedObject as? String ?? ""
        draftControllerID = identifier.isEmpty ? nil : identifier
        bindingCapture.cancel()
        refreshEditor()
        updatePreview()
    }

    private func updatePreview() {
        refreshControllers()
        let supported = supportedButtons?(draftControllerID)
        for (index, item) in source.itemArray.enumerated() {
            item.isEnabled = supported?.contains(index) ?? true
        }
        guard let state = preview?(draft, draftControllerID) else {
            previewStatus.stringValue =
                draftControllerID == nil
                ? controllerConfigurationIntl.noControllerHint
                : controllerConfigurationIntl.disconnectedControllerHint
            joystick.showInput(buttons: 0, x: 0, y: 0)
            fullKeyboard.showAssignments(draft)
            return
        }
        if draft.keyboardLayout == true {
            if let input = bindingCapture.consume(state.inputs) {
                if selectedKey == -2 {
                    guard (8..<18).contains(input) else {
                        bindingCapture.begin()
                        return
                    }
                    var buttons = Set(draft.mouseButtonInputs ?? [])
                    buttons.insert(input - 8)
                    draft.mouseButtonInputs = buttons.sorted()
                    draft.removeMouseInput(input)
                    bindInput(input, to: -1)
                } else if selectedKey == -3 {
                    let source = input < 8 ? 0 : ((18..<26).contains(input) ? 1 : (input >= 26 ? 2 : -1))
                    guard source >= 0 else {
                        bindingCapture.begin()
                        return
                    }
                    draft.prepareKeyboardBindings()
                    draft.mouseMovementSource = source
                    draft.mouseDirectionInputs = nil
                    if source < 2 {
                        draft.keyboardStickKeys!.replaceSubrange(
                            (source * 8)..<(source * 8 + 8), with: Array(repeating: -1, count: 8))
                        for axis in 0..<2 where draft.keyboardDpadAxisOwners![axis] == source {
                            draft.keyboardDpadAxisOwners![axis] = -1
                        }
                    } else {
                        draft.keyboardDpadKeys = Array(repeating: -1, count: 8)
                        draft.keyboardDpadAxisOwners = [-1, -1]
                    }
                } else if selectedKey <= -4 {
                    var directions = draft.mouseDirections.map { $0.filter { $0 != input } }
                    let direction = -selectedKey - 4
                    if !directions[direction].contains(input) { directions[direction].append(input) }
                    draft.mouseDirectionInputs = directions
                    draft.mouseMovementSource = nil
                    bindInput(input, to: -1)
                    if (8..<18).contains(input) { draft.mouseButtonInputs?.removeAll { $0 == input - 8 } }
                } else {
                    draft.removeMouseInput(input)
                    if (8..<18).contains(input) { draft.mouseButtonInputs?.removeAll { $0 == input - 8 } }
                    bindInput(input, to: selectedKey)
                }
                refreshEditor()
                window.makeFirstResponder(nil)
            }
            fullKeyboard.showAssignments(draft, pressedKeys: state.keys)
        }
        previewStatus.stringValue = controllerConfigurationIntl.liveInputPreview
        joystick.showInput(buttons: state.buttons, x: state.x, y: state.y)
    }

    @objc private func cancel(_ sender: Any?) { window.close() }

    @objc private func save(_ sender: Any?) {
        draft.save()
        completion?(draft, draftControllerID)
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        bindingCapture.cancel()
        didClose?()
        didClose = nil
        previewTimer?.invalidate()
        previewTimer = nil
        preview = nil
        completion = nil
        controllerChoices = nil
        supportedButtons = nil
    }
}
