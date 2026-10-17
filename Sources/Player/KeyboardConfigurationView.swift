import Cocoa

/// A complete IIGS keyboard; selecting a key arms controller-input binding in the panel.
final class KeyboardConfigurationView: NSView {
    static let bodyDepth: CGFloat = 230
    var keySelected: ((Int) -> Void)?
    var selectedKey = 49 { didSet { updateSelection() } }
    private var keys: [KeypadKey] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        let rows: [[(String, Int, CGFloat)]] = [
            [
                ("esc", 53, 1), ("1", 18, 1), ("2", 19, 1), ("3", 20, 1), ("4", 21, 1), ("5", 23, 1),
                ("6", 22, 1), ("7", 26, 1), ("8", 28, 1), ("9", 25, 1), ("0", 29, 1), ("−", 27, 1),
                ("=", 24, 1), ("delete", 51, 1.5),
            ],
            [
                ("tab", 48, 1.5), ("Q", 12, 1), ("W", 13, 1), ("E", 14, 1), ("R", 15, 1), ("T", 17, 1),
                ("Y", 16, 1), ("U", 32, 1), ("I", 34, 1), ("O", 31, 1), ("P", 35, 1), ("[", 33, 1),
                ("]", 30, 1),
            ],
            [
                ("control", 59, 1.75), ("A", 0, 1), ("S", 1, 1), ("D", 2, 1), ("F", 3, 1), ("G", 5, 1),
                ("H", 4, 1), ("J", 38, 1), ("K", 40, 1), ("L", 37, 1), (";", 41, 1), ("'", 39, 1),

            ],
            [
                ("shift", 56, 2.25), ("Z", 6, 1), ("X", 7, 1), ("C", 8, 1), ("V", 9, 1), ("B", 11, 1),
                ("N", 45, 1), ("M", 46, 1), (",", 43, 1), (".", 47, 1), ("/", 44, 1), ("shift", 56, 2.25),
            ],
            [
                ("caps\nlock", 57, 1), ("option", 58, 1), ("⌘", 55, 1.75), ("`", 50, 1),
                ("space", 49, 4.75), ("\\", 42, 1), ("←", 123, 1), ("→", 124, 1), ("↓", 125, 1),
                ("↑", 126, 1),
            ],
        ]
        for (row, entries) in rows.enumerated() {
            var x: CGFloat = 16
            for (title, code, width) in entries {
                addKey(title, code: code, x: x, y: 202 - CGFloat(row) * 42, width: width * 44)
                x += width * 44
            }
        }
        let pad: [[(String, Int)]] = [
            [("clear", 71), ("=", 81), ("/", 75), ("*", 67)],
            [("7", 89), ("8", 91), ("9", 92), ("+", 69)],
            [("4", 86), ("5", 87), ("6", 88), ("−", 78)],
            [("1", 83), ("2", 84), ("3", 85), ("enter", 76)],
            [("0", 82), (".", 65)],
        ]
        for (row, entries) in pad.enumerated() {
            for (column, key) in entries.enumerated() {
                if key.1 == 76 { continue }
                addKey(
                    key.0, code: key.1, x: 688 + CGFloat(row == 4 && column == 1 ? 2 : column) * 44,
                    y: 202 - CGFloat(row) * 42, width: key.1 == 82 ? 88 : 44)
            }
        }
        addKey("enter", code: 76, x: 820, y: 34, width: 44, height: 82)
        addKey("return", code: 36, x: 577, y: 118, width: 77, height: 82)
        keys.last?.returnNotch = 33
        updateSelection()
    }

    required init?(coder: NSCoder) { return nil }

    private func addKey(
        _ title: String, code: Int, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat = 40
    ) {
        let key = KeypadKey(title: title, code: code, frame: NSRect(x: x, y: y, width: width, height: height))
        key.compact = true
        key.target = self
        key.action = #selector(selectKey(_:))
        key.font = .systemFont(ofSize: 12)
        key.setAccessibilityLabel(ControllerMapping.keyChoices.first { $0.1 == code }?.0 ?? title)
        addSubview(key)
        keys.append(key)
    }

    @objc private func selectKey(_ sender: KeypadKey) {
        selectedKey = sender.code
        keySelected?(sender.code)
    }

    private func updateSelection() {
        for key in keys { key.selected = key.code == selectedKey }
    }

    func showAssignments(_ mapping: ControllerMapping, pressedKeys: Set<Int32> = []) {
        let directions = ["←", "→", "↑", "↓", "↖", "↗", "↙", "↘"]
        let buttons = ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "Start", "Select"]
        let labels =
            directions.map { "L" + $0 } + buttons + directions.map { "R" + $0 } + directions.map { "D" + $0 }
        var assigned: [Int: [String]] = [:]
        let codes = mapping.keyboardInputKeys
        let owners = mapping.keyboardDpadAxisOwners ?? [-1, -1]
        for index in codes.indices where codes[index] >= 0 {
            if index >= 26 {
                let direction = index - 26
                let axes = direction < 2 ? [0] : (direction < 4 ? [1] : [0, 1])
                if !axes.allSatisfy({ owners[$0] == -1 }) { continue }
            }
            assigned[codes[index], default: []].append(labels[index])
        }
        for direction in 0..<8 {
            let axes = direction < 2 ? [0] : (direction < 4 ? [1] : [0, 1])
            if let owner = axes.map({ owners[$0] }).first, owner >= 0,
                axes.allSatisfy({ owners[$0] == owner })
            {
                let code = codes[(owner == 0 ? 0 : 18) + direction]
                if code >= 0 { assigned[code, default: []].append("D" + directions[direction]) }
            }
        }
        for key in keys {
            let inputs = assigned[key.code] ?? []
            key.assignmentBadges = inputs.map { KeyAssignmentBadge(input: $0) }
            key.active = pressedKeys.contains(Int32(key.code))
            key.toolTip = inputs.isEmpty ? "Click to bind a controller input" : inputs.joined(separator: ", ")
            key.setAccessibilityValue(inputs.isEmpty ? "Unassigned" : inputs.joined(separator: ", "))
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let plastic = NSColor(calibratedRed: 0.78, green: 0.77, blue: 0.68, alpha: 1)
        plastic.setFill()
        NSBezierPath(roundedRect: NSRect(x: 120, y: 236, width: 650, height: 50), xRadius: 6, yRadius: 6)
            .fill()
        NSBezierPath(
            roundedRect: NSRect(x: 2, y: 20, width: bounds.width - 4, height: Self.bodyDepth), xRadius: 12,
            yRadius: 12
        ).fill()
        NSColor(calibratedWhite: 0.30, alpha: 0.45).setStroke()
        let well = NSBezierPath(
            roundedRect: NSRect(x: 10, y: 26, width: bounds.width - 20, height: 220), xRadius: 8, yRadius: 8)
        well.lineWidth = 2
        well.stroke()
        let power = NSBezierPath(
            roundedRect: NSRect(x: 230, y: 250, width: 88, height: 28), xRadius: 3, yRadius: 3)
        NSColor(calibratedWhite: 0.43, alpha: 1).setFill()
        power.fill()
        plastic.highlight(withLevel: 0.1)?.setFill()
        NSBezierPath(roundedRect: NSRect(x: 232, y: 253, width: 83, height: 24), xRadius: 2, yRadius: 2)
            .fill()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: NSColor(calibratedWhite: 0.28, alpha: 1),
        ]
        "◁".draw(at: NSPoint(x: 242, y: 255), withAttributes: attributes)
        for (index, color) in [
            NSColor.systemGreen, .systemYellow, .systemOrange, .systemRed, .systemPurple, .systemBlue,
        ].enumerated() {
            color.setFill()
            NSBezierPath(rect: NSRect(x: 170, y: 254 + CGFloat(index) * 3, width: 14, height: 3)).fill()
        }
    }
}

/// Requires a neutral sample after selecting a key so an already-held control cannot bind accidentally.
struct ControllerBindingCapture {
    private(set) var armed = false
    private var waitingForNeutral = true

    mutating func begin() {
        armed = true
        waitingForNeutral = true
    }

    mutating func cancel() { armed = false }

    mutating func consume(_ inputs: Set<Int>) -> Int? {
        guard armed else { return nil }
        if inputs.isEmpty {
            waitingForNeutral = false
            return nil
        }
        guard !waitingForNeutral, inputs.count == 1 else { return nil }
        armed = false
        return inputs.first
    }
}

/// A single-button ADB mouse with independently bindable directions around its shell.
final class ADBMouseConfigurationView: NSView {
    static let bodyRect = NSRect(x: 56, y: 54, width: 128, height: KeyboardConfigurationView.bodyDepth)
    var controlSelected: ((Int) -> Void)?
    private let mouseButton = KeypadKey(
        title: "", code: -2, frame: NSRect(x: 64, y: 218, width: 112, height: 60))
    private let motion = NSButton(title: "✥", target: nil, action: nil)
    private var directions: [KeypadKey] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        mouseButton.compact = true
        mouseButton.target = self
        mouseButton.action = #selector(selectControl(_:))
        mouseButton.tag = -2
        mouseButton.setAccessibilityLabel("Bind ADB mouse button")
        addSubview(mouseButton)
        motion.frame = NSRect(x: 64, y: 70, width: 112, height: 140)
        motion.isBordered = false
        motion.target = self
        motion.action = #selector(selectControl(_:))
        motion.tag = -3
        motion.setAccessibilityLabel("Bind ADB mouse movement")
        motion.toolTip = "Click, then move either stick or the D-pad to bind all four mouse directions"
        addSubview(motion)
        let positions: [(CGFloat, CGFloat)] = [(0, 149), (200, 149), (100, 294), (100, 8)]
        for (index, symbol) in ["←", "→", "↑", "↓"].enumerated() {
            let arrow = KeypadKey(
                title: symbol, code: -4 - index,
                frame: NSRect(x: positions[index].0, y: positions[index].1, width: 40, height: 40))
            arrow.compact = true
            arrow.tag = -4 - index
            arrow.target = self
            arrow.action = #selector(selectControl(_:))
            arrow.setAccessibilityLabel("Bind mouse " + ["left", "right", "up", "down"][index])
            addSubview(arrow)
            directions.append(arrow)
        }
    }

    required init?(coder: NSCoder) { return nil }
    @objc private func selectControl(_ sender: NSButton) { controlSelected?(sender.tag) }

    func showAssignments(_ mapping: ControllerMapping, selectedControl: Int?) {
        mouseButton.selected = selectedControl == -2
        let arrows = ["←", "→", "↑", "↓", "↖", "↗", "↙", "↘"]
        let buttons = ["A", "B", "X", "Y", "LB", "RB", "LT", "RT", "Start", "Select"]
        let labels = arrows.map { "L" + $0 } + buttons + arrows.map { "R" + $0 } + arrows.map { "D" + $0 }
        mouseButton.assignmentBadges = (mapping.mouseButtonInputs ?? []).map {
            KeyAssignmentBadge(input: buttons[$0])
        }
        motion.contentTintColor = selectedControl == -3 ? .controlAccentColor : .secondaryLabelColor
        for (index, arrow) in directions.enumerated() {
            let inputs = mapping.mouseDirections[index].map { labels[$0] }
            arrow.assignmentBadges = inputs.map { KeyAssignmentBadge(input: $0) }
            arrow.selected = selectedControl == -4 - index
            arrow.toolTip =
                inputs.isEmpty ? "Click to bind this mouse direction" : inputs.joined(separator: ", ")
            arrow.setAccessibilityValue(inputs.isEmpty ? "Unassigned" : inputs.joined(separator: ", "))
        }
        mouseButton.toolTip =
            "Mouse click: "
            + ((mapping.mouseButtonInputs ?? []).isEmpty
                ? "Unassigned"
                : (mapping.mouseButtonInputs ?? []).map { ControllerMapping.buttonNames[$0] }.joined(
                    separator: ", "))
    }

    override func draw(_ dirtyRect: NSRect) {
        let cable = NSBezierPath()
        cable.move(to: NSPoint(x: 120, y: 280))
        cable.curve(
            to: NSPoint(x: 142, y: 307), controlPoint1: NSPoint(x: 120, y: 298),
            controlPoint2: NSPoint(x: 135, y: 303))
        NSColor(calibratedRed: 0.64, green: 0.63, blue: 0.54, alpha: 1).setStroke()
        cable.lineWidth = 4
        cable.stroke()
        NSColor(calibratedRed: 0.78, green: 0.77, blue: 0.68, alpha: 1).setFill()
        let body = NSBezierPath(
            roundedRect: Self.bodyRect, xRadius: 14, yRadius: 14)
        body.fill()
        NSColor(calibratedWhite: 0.4, alpha: 0.5).setStroke()
        body.lineWidth = 1
        body.stroke()
    }
}
