import Cocoa
import GameController

/// Per-player controller preferences persisted in user defaults.
struct ControllerMapping: Codable {
    var keyboardMode: Bool? = false
    var keyCodes: [Int]? = nil

    /// Default virtual keys: keypad 4/6/8/5, Command, and Option.
    static let defaultKeyCodes = [86, 88, 91, 87, 55, 58]
    static let keyChoices: [(String, Int)] = [
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
                    && value.keyCodes!.allSatisfy { code in keyChoices.contains { $0.1 == code } })
        else {
            return Self()
        }
        return value
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

final class ControllerMappingPanel: NSObject {
    private var window: NSWindow!
    private let targetMode = NSPopUpButton(frame: .zero)
    private var keyPopups: [NSPopUpButton] = []
    private let movement = NSPopUpButton(frame: .zero)
    private let button0 = NSPopUpButton(frame: .zero)
    private let button1 = NSPopUpButton(frame: .zero)
    private let invertX = NSButton(checkboxWithTitle: "Invert horizontal axis", target: nil, action: nil)
    private let invertY = NSButton(checkboxWithTitle: "Invert vertical axis", target: nil, action: nil)
    private let deadZone = NSSlider(value: 8, minValue: 8, maxValue: 30, target: nil, action: nil)
    private let deadZoneLabel = NSTextField(labelWithString: "Dead zone: 8%")
    private var completion: ((ControllerMapping) -> Void)?

    func show(
        mapping: ControllerMapping, controllerName: String, completion: @escaping (ControllerMapping) -> Void
    ) {
        self.completion = completion
        if window == nil {
            build()
        }
        targetMode.selectItem(at: mapping.keyboardMode == true ? 1 : 0)
        let keys = mapping.keyCodes ?? ControllerMapping.defaultKeyCodes
        for (index, popup) in keyPopups.enumerated() {
            popup.selectItem(at: ControllerMapping.keyChoices.firstIndex(where: { $0.1 == keys[index] }) ?? 0)
        }
        updateMode(nil)
        movement.selectItem(at: mapping.movement)
        button0.selectItem(at: mapping.button0)
        button1.selectItem(at: mapping.button1)
        invertX.state = mapping.invertX ? .on : .off
        invertY.state = mapping.invertY ? .on : .off
        deadZone.doubleValue = Double(mapping.deadZone * 100)
        updateDeadZone(nil)
        window.title = "Apple II Joystick — " + controllerName
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func build() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 620), styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let root = window.contentView!
        let description = NSTextField(
            wrappingLabelWithString:
                "Map your controller to the classic Apple II analog joystick, or send keypad/Apple-key presses for keyboard-controlled games."
        )
        description.frame = NSRect(x: 24, y: 552, width: 472, height: 44)
        root.addSubview(description)
        for (label, popup, y) in [
            ("Joystick movement", movement, 468), ("Joystick button 0", button0, 426),
            ("Joystick button 1", button1, 384),
        ] {
            let text = NSTextField(labelWithString: label)
            text.sizeToFit()
            text.frame.origin = CGPoint(x: 24, y: CGFloat(y) + (28 - text.frame.height) / 2)
            root.addSubview(text)
            popup.frame = NSRect(x: 212, y: y, width: 284, height: 28)
            root.addSubview(popup)
        }

        let targetLabel = NSTextField(labelWithString: "Emulated controls")
        targetLabel.sizeToFit()
        targetLabel.frame.origin = CGPoint(x: 24, y: 510 + (28 - targetLabel.frame.height) / 2)
        root.addSubview(targetLabel)
        targetMode.frame = NSRect(x: 212, y: 510, width: 284, height: 28)
        targetMode.addItems(withTitles: ["Apple II Analog Joystick", "Numeric Keypad / Apple Keys"])
        targetMode.target = self
        targetMode.action = #selector(updateMode(_:))
        root.addSubview(targetMode)
        for (index, name) in ["Left", "Right", "Up", "Down", "Primary button", "Secondary button"]
            .enumerated()
        {
            let y = CGFloat(258 - index * 32)
            let label = NSTextField(labelWithString: name + " key")
            label.sizeToFit()
            label.frame.origin = CGPoint(x: 24, y: y + (26 - label.frame.height) / 2)
            root.addSubview(label)
            let popup = NSPopUpButton(frame: NSRect(x: 212, y: y, width: 284, height: 26))
            popup.addItems(withTitles: ControllerMapping.keyChoices.map { $0.0 })
            root.addSubview(popup)
            keyPopups.append(popup)
        }
        movement.addItems(withTitles: ControllerMapping.movementNames)
        button0.addItems(withTitles: ControllerMapping.buttonNames)
        button1.addItems(withTitles: ControllerMapping.buttonNames)
        invertX.frame = NSRect(x: 24, y: 340, width: 230, height: 24)
        root.addSubview(invertX)
        invertY.frame = NSRect(x: 266, y: 340, width: 230, height: 24)
        root.addSubview(invertY)
        deadZoneLabel.frame = NSRect(x: 24, y: 298, width: 180, height: 24)
        root.addSubview(deadZoneLabel)
        deadZone.frame = NSRect(x: 212, y: 298, width: 284, height: 24)
        deadZone.target = self
        deadZone.action = #selector(updateDeadZone(_:))
        root.addSubview(deadZone)
        let reset = NSButton(title: "Restore Defaults", target: self, action: #selector(reset(_:)))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 24, y: 26, width: 160, height: 32)
        root.addSubview(reset)
        let save = NSButton(title: "Save", target: self, action: #selector(save(_:)))
        save.bezelStyle = .rounded
        save.frame = NSRect(x: 376, y: 26, width: 120, height: 32)
        save.keyEquivalent = "\r"
        root.addSubview(save)
    }

    @objc private func updateMode(_ sender: Any?) {
        for popup in keyPopups {
            popup.isEnabled = targetMode.indexOfSelectedItem == 1
        }
    }

    @objc private func updateDeadZone(_ sender: Any?) {
        deadZoneLabel.stringValue = "Dead zone: \(Int(deadZone.doubleValue.rounded()))%"
    }

    @objc private func reset(_ sender: Any?) {
        targetMode.selectItem(at: 0)
        for (index, popup) in keyPopups.enumerated() {
            popup.selectItem(
                at: ControllerMapping.keyChoices.firstIndex(where: {
                    $0.1 == ControllerMapping.defaultKeyCodes[index]
                })!)
        }
        updateMode(nil)
        movement.selectItem(at: 0)
        button0.selectItem(at: 0)
        button1.selectItem(at: 1)
        invertX.state = .off
        invertY.state = .off
        deadZone.doubleValue = 8
        updateDeadZone(nil)
    }

    @objc private func save(_ sender: Any?) {
        var mapping = ControllerMapping()
        mapping.keyboardMode = targetMode.indexOfSelectedItem == 1
        mapping.keyCodes = keyPopups.map { ControllerMapping.keyChoices[$0.indexOfSelectedItem].1 }
        mapping.movement = movement.indexOfSelectedItem
        mapping.button0 = button0.indexOfSelectedItem
        mapping.button1 = button1.indexOfSelectedItem
        mapping.invertX = invertX.state == .on
        mapping.invertY = invertY.state == .on
        mapping.deadZone = Float(deadZone.doubleValue.rounded()) / 100
        mapping.save()
        completion?(mapping)
        window.orderOut(nil)
    }
}
