import Cocoa
import GameController

/// Per-player controller preferences persisted in user defaults.
struct ControllerMapping: Codable {
    var keyboardMode: Bool? = false
    var keyCodes: [Int]? = nil

    /// Explicit diagonal keys (upper left/right, lower left/right); nil preserves legacy combined presses.
    var diagonalKeyCodes: [Int]? = nil

    /// Keys sent by the eight physical controller buttons; -1 leaves a button unassigned.
    /// Nil preserves the older two-button mapping stored in `keyCodes`.
    var keyboardButtonKeyCodes: [Int]? = nil

    /// Default virtual keys: keypad 4/6/8/5, Command, and Option.
    static let defaultKeyCodes = [86, 88, 91, 87, 55, 58]
    static let keyChoices: [(String, Int)] = [
        ("Keypad 7", 89), ("Keypad 9", 92), ("Keypad 1", 83), ("Keypad 3", 85),
        ("Keypad 0", 82), ("Keypad .", 65), ("Keypad Enter", 76), ("Keypad Clear", 71),
        ("Keypad =", 81), ("Keypad /", 75), ("Keypad *", 67), ("Keypad -", 78), ("Keypad +", 69),
        ("Keypad 4", 86), ("Keypad 6", 88), ("Keypad 8", 91), ("Keypad 5", 87), ("Keypad 2", 84),
        ("Command / Open Apple", 55), ("Option / Closed Apple", 58), ("Left arrow", 123),
        ("Right arrow", 124), ("Up arrow", 126), ("Down arrow", 125), ("Space", 49), ("Return", 36), ("A", 0),
        ("D", 2), ("W", 13), ("S", 1),
    ]

    /// Movement source: 0 uses the left stick with D-pad override, 1 the right stick, and 2 the D-pad.
    var movement = 0
    var button0 = 0
    var button1 = 1
    var invertX = false
    var invertY = false
    var deadZone: Float = 0.08
    static let buttonNames = [
        "A", "B", "X", "Y", "Left shoulder", "Right shoulder", "Left trigger", "Right trigger",
    ]
    static let movementNames = ["Left analog stick + D-pad", "Right analog stick", "D-pad"]
    static let defaultsKey = "AppleIIControllerMapping"

    /// Returns saved settings, or defaults if decoding or range validation fails.
    static func load() -> ControllerMapping {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
            let value = try? JSONDecoder().decode(Self.self, from: data),
            (0..<3).contains(value.movement), buttonNames.indices.contains(value.button0),
            buttonNames.indices.contains(value.button1),
            value.deadZone.isFinite, (0.08...0.30).contains(value.deadZone),
            value.keyCodes == nil
                || (value.keyCodes!.count == 6
                    && value.keyCodes!.allSatisfy { code in code == -1 || keyChoices.contains { $0.1 == code }
                    })
        else {
            return Self()
        }
        let validCodes = Set(keyChoices.map { $0.1 } + [-1])
        guard
            value.diagonalKeyCodes == nil
                || (value.diagonalKeyCodes!.count == 4
                    && value.diagonalKeyCodes!.allSatisfy({ validCodes.contains($0) })),
            value.keyboardButtonKeyCodes == nil
                || (value.keyboardButtonKeyCodes!.count == 8
                    && value.keyboardButtonKeyCodes!.allSatisfy({ validCodes.contains($0) }))
        else { return Self() }
        return value
    }

    /// Effective keyboard assignments, including legacy defaults for existing players.
    var directionKeys: [Int] {
        Array((keyCodes ?? Self.defaultKeyCodes).prefix(4)) + (diagonalKeyCodes ?? [-1, -1, -1, -1])
    }

    var buttonKeys: [Int] {
        if let keys = keyboardButtonKeyCodes { return keys }
        let keys = keyCodes ?? Self.defaultKeyCodes
        var result = Array(repeating: -1, count: 8)
        result[button0] = keys[4]
        result[button1] = keys[5]
        return result
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

    func button(_ index: Int, on pad: GCExtendedGamepad) -> GCControllerButtonInput {
        [
            pad.buttonA, pad.buttonB, pad.buttonX, pad.buttonY, pad.leftShoulder, pad.rightShoulder,
            pad.leftTrigger, pad.rightTrigger,
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
    private var window: NSWindow!
    private var draft = ControllerMapping()
    private let joystick = JoystickConfigurationView(frame: NSRect(x: 28, y: 128, width: 440, height: 440))
    private let keypad = KeypadConfigurationView(frame: NSRect(x: 28, y: 92, width: 440, height: 460))
    private let targetMode = NSPopUpButton(frame: .zero)
    private let keySelector = NSPopUpButton(frame: .zero)
    private var assignmentHeadings: [NSTextField] = []
    private let selectionTitle = NSTextField(labelWithString: "")
    private let explanation = NSTextField(wrappingLabelWithString: "")
    private let sourceLabel = NSTextField(labelWithString: "")
    private let source = NSPopUpButton(frame: .zero)
    private let movementLabel = NSTextField(labelWithString: "Controller movement")
    private let movement = NSPopUpButton(frame: .zero)
    private let invertX = NSButton(checkboxWithTitle: "Invert horizontal", target: nil, action: nil)
    private let invertY = NSButton(checkboxWithTitle: "Invert vertical", target: nil, action: nil)
    private let deadZone = NSSlider(value: 8, minValue: 8, maxValue: 30, target: nil, action: nil)
    private let deadZoneLabel = NSTextField(labelWithString: "Dead zone: 8%")
    private let heading = NSTextField(labelWithString: "")
    private let device = NSPopUpButton(frame: .zero)
    private let previewStatus = NSTextField(labelWithString: "")
    private var controllerChoices: (() -> [ControllerChoice])?
    private var lastChoices: [ControllerChoice] = []
    private var draftControllerID: String?
    private var selectedControllerName = "Controller"
    private let keypadDefaults = NSButton(title: "Keypad Defaults", target: nil, action: nil)
    private var assignments: [NSButton] = []
    private let directions = [
        "Left", "Right", "Up", "Down", "Upper left", "Upper right", "Lower left", "Lower right",
    ]
    private var selectedKey = 87
    private var previewTimer: Timer?
    private var preview:
        ((ControllerMapping, String?) -> (buttons: UInt32, x: Int32, y: Int32, keys: Set<Int32>)?)?
    private var completion: ((ControllerMapping, String?) -> Void)?

    func show(
        mapping: ControllerMapping, controllers: @escaping () -> [ControllerChoice],
        selectedControllerID: String?,
        preview:
            @escaping (ControllerMapping, String?) -> (buttons: UInt32, x: Int32, y: Int32, keys: Set<Int32>)?,
        completion: @escaping (ControllerMapping, String?) -> Void
    ) {
        if window == nil { build() }
        self.completion = completion
        self.preview = preview
        self.controllerChoices = controllers
        draftControllerID = selectedControllerID
        draft = mapping
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
        window.title = "Configure Controls"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let root = window.contentView!
        heading.font = .systemFont(ofSize: 26, weight: .semibold)
        heading.frame = NSRect(x: 28, y: 662, width: 880, height: 34)
        root.addSubview(heading)
        let subtitle = NSTextField(
            labelWithString: "Choose a control on the left, then assign your controller on the right.")
        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = NSRect(x: 28, y: 634, width: 880, height: 24)
        root.addSubview(subtitle)
        let controllerLabel = NSTextField(labelWithString: "Controller")
        controllerLabel.frame = NSRect(x: 28, y: 604, width: 80, height: 22)
        controllerLabel.textColor = .secondaryLabelColor
        root.addSubview(controllerLabel)
        device.frame = NSRect(x: 112, y: 600, width: 346, height: 28)
        device.target = self
        device.action = #selector(selectController(_:))
        device.setAccessibilityLabel("Active game controller")
        device.toolTip =
            "Select a controller for this running player. Automatic is restored on the next launch."
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
        root.addSubview(keypad)
        joystick.selectionChanged = { [weak self] _ in self?.refreshEditor() }
        keypad.keySelected = { [weak self] code in
            self?.selectedKey = code
            self?.refreshEditor()
        }
        targetMode.frame = NSRect(x: 28, y: 552, width: 430, height: 28)
        targetMode.addItems(withTitles: ["Apple II Analog Joystick", "Numeric Keypad / Apple Keys"])
        targetMode.target = self
        targetMode.action = #selector(changeMode(_:))
        root.addSubview(targetMode)
        selectionTitle.font = .systemFont(ofSize: 23, weight: .semibold)
        selectionTitle.frame = NSRect(x: 500, y: 538, width: 400, height: 32)
        root.addSubview(selectionTitle)
        keySelector.frame = NSRect(x: 710, y: 540, width: 190, height: 28)
        for choice in ControllerMapping.keyChoices {
            keySelector.addItem(withTitle: choice.0)
            keySelector.lastItem?.tag = choice.1
        }
        keySelector.target = self
        keySelector.action = #selector(selectKey(_:))
        keySelector.setAccessibilityLabel("Choose an emulated key, including other keyboard keys")
        root.addSubview(keySelector)
        for (title, x) in [("MOVEMENT", 500), ("CONTROLLER BUTTONS", 708)] {
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 10, weight: .semibold)
            label.textColor = .secondaryLabelColor
            label.frame = NSRect(x: x, y: 468, width: 200, height: 16)
            root.addSubview(label)
            assignmentHeadings.append(label)
        }
        explanation.textColor = .secondaryLabelColor
        explanation.frame = NSRect(x: 500, y: 482, width: 410, height: 48)
        root.addSubview(explanation)
        sourceLabel.frame = NSRect(x: 500, y: 444, width: 400, height: 22)
        root.addSubview(sourceLabel)
        source.frame = NSRect(x: 500, y: 406, width: 400, height: 28)
        source.target = self
        source.action = #selector(changeSource(_:))
        root.addSubview(source)
        for index in 0..<16 {
            let title = index < 8 ? directions[index] : ControllerMapping.buttonNames[index - 8]
            let button = NSButton(checkboxWithTitle: title, target: self, action: #selector(assignKey(_:)))
            button.tag = index
            button.frame = NSRect(
                x: index < 8 ? 500 : 708, y: 443 - (index % 8) * 25,
                width: 200, height: 24)
            root.addSubview(button)
            assignments.append(button)
        }
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
        deadZone.setAccessibilityLabel("Controller dead zone")
        root.addSubview(deadZone)
        let hint = NSTextField(
            labelWithString: "Move your controller to preview. Click a control to assign it.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        hint.frame = NSRect(x: 28, y: 78, width: 440, height: 20)
        root.addSubview(hint)
        let reset = NSButton(title: "Restore Defaults", target: self, action: #selector(reset(_:)))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 28, y: 18, width: 154, height: 32)
        root.addSubview(reset)
        keypadDefaults.target = self
        keypadDefaults.action = #selector(useKeypadDefaults(_:))
        keypadDefaults.bezelStyle = .rounded
        keypadDefaults.frame = NSRect(x: 196, y: 18, width: 154, height: 32)
        root.addSubview(keypadDefaults)
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel(_:)))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        cancel.frame = NSRect(x: 688, y: 18, width: 100, height: 32)
        root.addSubview(cancel)
        let save = NSButton(title: "Save", target: self, action: #selector(save(_:)))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.frame = NSRect(x: 800, y: 18, width: 112, height: 32)
        root.addSubview(save)
    }

    private func refresh() {
        targetMode.selectItem(at: draft.keyboardMode == true ? 1 : 0)
        movement.selectItem(at: draft.movement)
        invertX.state = draft.invertX ? .on : .off
        invertY.state = draft.invertY ? .on : .off
        deadZone.doubleValue = Double(draft.deadZone * 100)
        deadZoneLabel.stringValue = "Dead zone: \(Int(deadZone.doubleValue.rounded()))%"
        joystick.showAssignments(draft)
        refreshEditor()
    }

    private func refreshEditor() {
        let keyboard = draft.keyboardMode == true
        heading.stringValue = keyboard ? "🔢 Numpad Settings" : "🕹️ Joystick Settings"
        joystick.isHidden = keyboard
        keypad.isHidden = !keyboard
        keypadDefaults.isHidden = !keyboard
        keySelector.isHidden = !keyboard
        for label in assignmentHeadings { label.isHidden = !keyboard }
        source.isHidden = keyboard || joystick.selectedControl.isDirection
        sourceLabel.isHidden = source.isHidden
        for button in assignments { button.isHidden = !keyboard }
        let movementY: CGFloat = keyboard ? 192 : (joystick.selectedControl.isDirection ? 406 : 288)
        movement.frame.origin.y = movementY
        movementLabel.frame.origin.y = movementY + 36
        let axesY: CGFloat = keyboard ? 148 : movementY - 56
        invertX.frame.origin.y = axesY
        invertY.frame.origin.y = axesY
        deadZoneLabel.frame.origin.y = axesY - 40
        deadZone.frame.origin.y = axesY - 40
        if keyboard {
            selectionTitle.stringValue = "Key assignment"
            keySelector.selectItem(withTag: selectedKey)
            explanation.stringValue =
                "Choose every controller input that should press this key. A new assignment replaces that input’s previous key."
            let keys = draft.directionKeys + draft.buttonKeys
            for button in assignments {
                button.state = keys[button.tag] == selectedKey ? .on : .off
                let current =
                    ControllerMapping.keyChoices.first(where: { $0.1 == keys[button.tag] })?.0 ?? "Unassigned"
                button.toolTip = "Current assignment: \(current)"
            }
            keypad.selectedKey = selectedKey
            keypad.showAssignments(draft)
        } else {
            let control = joystick.selectedControl
            selectionTitle.stringValue =
                control.isDirection ? "\(control.label) direction" : "Joystick \(control.label.lowercased())"
            explanation.stringValue =
                control.isDirection
                ? "All four directions follow the movement source below. Move your controller to test the stick and orange buttons."
                : "Choose the controller button that should press this orange joystick button."
            if !control.isDirection {
                sourceLabel.stringValue = "Controller button"
                source.removeAllItems()
                source.addItems(withTitles: ControllerMapping.buttonNames)
                source.selectItem(at: control == .button0 ? draft.button0 : draft.button1)
                source.setAccessibilityLabel("\(control.label) controller assignment")
            }
        }
    }

    @objc private func selectKey(_ sender: Any?) {
        selectedKey = keySelector.selectedTag()
        refreshEditor()
    }

    @objc private func changeMode(_ sender: Any?) {
        draft.keyboardMode = targetMode.indexOfSelectedItem == 1
        if draft.keyboardMode == true, draft.keyCodes == nil, draft.diagonalKeyCodes == nil,
            draft.keyboardButtonKeyCodes == nil
        {
            useKeypadDefaults(nil)
        } else {
            refresh()
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
        deadZoneLabel.stringValue = "Dead zone: \(Int(deadZone.doubleValue.rounded()))%"
    }

    @objc private func assignKey(_ sender: NSButton) {
        let code = sender.state == .on ? selectedKey : -1
        if sender.tag < 4 {
            var keys = draft.keyCodes ?? ControllerMapping.defaultKeyCodes
            keys[sender.tag] = code
            draft.keyCodes = keys
        } else if sender.tag < 8 {
            var keys = draft.diagonalKeyCodes ?? [-1, -1, -1, -1]
            keys[sender.tag - 4] = code
            draft.diagonalKeyCodes = keys
        } else {
            var keys = draft.buttonKeys
            keys[sender.tag - 8] = code
            draft.keyboardButtonKeyCodes = keys
        }
        refreshEditor()
    }

    @objc private func useKeypadDefaults(_ sender: Any?) {
        draft.keyCodes = [86, 88, 91, 84, 55, 58]
        draft.diagonalKeyCodes = [89, 92, 83, 85]
        draft.keyboardButtonKeyCodes = [55, 58, -1, -1, -1, -1, -1, -1]
        refresh()
    }

    @objc private func reset(_ sender: Any?) {
        draft = ControllerMapping()
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
        device.addItem(withTitle: "Automatic")
        device.lastItem?.representedObject = ""
        for choice in choices {
            device.addItem(withTitle: choice.name)
            device.lastItem?.representedObject = choice.id
        }
        if let identifier = draftControllerID, !choices.contains(where: { $0.id == identifier }) {
            device.addItem(withTitle: "\(selectedControllerName) (disconnected)")
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
        updatePreview()
    }

    private func updatePreview() {
        refreshControllers()
        guard let state = preview?(draft, draftControllerID) else {
            previewStatus.stringValue =
                draftControllerID == nil
                ? "No controller connected · Assignments can still be edited."
                : "Selected controller disconnected · Choose a connected controller."
            joystick.showInput(buttons: 0, x: 0, y: 0)
            keypad.showPressedKeys([])
            return
        }
        previewStatus.stringValue = "Live input preview"
        joystick.showInput(buttons: state.buttons, x: state.x, y: state.y)
        keypad.showPressedKeys(state.keys)
    }

    @objc private func cancel(_ sender: Any?) { window.close() }

    @objc private func save(_ sender: Any?) {
        draft.save()
        completion?(draft, draftControllerID)
        window.close()
    }

    func windowWillClose(_ notification: Notification) {
        previewTimer?.invalidate()
        previewTimer = nil
        preview = nil
        completion = nil
        controllerChoices = nil
    }
}
