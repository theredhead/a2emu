import Cocoa

private let keyboardConfigurationIntl = KeyboardConfigurationIntl()
private let commonIntl = CommonIntl()

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
        mouseButton.setAccessibilityLabel(keyboardConfigurationIntl.bindAdbMouseButton)
        addSubview(mouseButton)
        motion.frame = NSRect(x: 64, y: 70, width: 112, height: 140)
        motion.isBordered = false
        motion.target = self
        motion.action = #selector(selectControl(_:))
        motion.tag = -3
        motion.setAccessibilityLabel(keyboardConfigurationIntl.bindAdbMouseMovement)
        motion.toolTip = keyboardConfigurationIntl.clickThenMoveEitherStickOr
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
            arrow.setAccessibilityLabel(
                keyboardConfigurationIntl.bindMouseDirection(
                    direction: JoystickControl.allCases[index].label.lowercased()))
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
                inputs.isEmpty
                ? keyboardConfigurationIntl.clickToBindThisMouseDirection : inputs.joined(separator: ", ")
            arrow.setAccessibilityValue(
                inputs.isEmpty ? commonIntl.unassigned : inputs.joined(separator: ", "))
        }
        mouseButton.toolTip =
            keyboardConfigurationIntl.mouseClickBindings(
                bindings: ((mapping.mouseButtonInputs ?? []).isEmpty
                    ? commonIntl.unassigned
                    : (mapping.mouseButtonInputs ?? []).map { ControllerMapping.buttonNames[$0] }.joined(
                        separator: ", ")))
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
