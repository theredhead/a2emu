import Cocoa

private let commonIntl = CommonIntl()
private let keyboardConfigurationIntl = KeyboardConfigurationIntl()

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
            key.toolTip =
                inputs.isEmpty
                ? keyboardConfigurationIntl.clickToBindAControllerInput : inputs.joined(separator: ", ")
            key.setAccessibilityValue(inputs.isEmpty ? commonIntl.unassigned : inputs.joined(separator: ", "))
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
