import Cocoa

private let joystickConfigurationIntl = JoystickConfigurationIntl()

/// The six assignable controls on the illustrated Apple II joystick.
enum JoystickControl: Int, CaseIterable {
    case left, right, up, down, button0, button1

    var label: String {
        switch self {
        case .left: return joystickConfigurationIntl.left
        case .right: return joystickConfigurationIntl.right
        case .up: return joystickConfigurationIntl.up
        case .down: return joystickConfigurationIntl.down
        case .button0: return joystickConfigurationIntl.button0
        case .button1: return joystickConfigurationIntl.button1
        }
    }

    var isDirection: Bool { rawValue < 4 }
}

/// A keyboard-accessible hotspot with a selection ring and live input feedback.
private final class JoystickHotspot: NSButton {
    let control: JoystickControl
    var selected = false { didSet { needsDisplay = true } }
    var active = false { didSet { needsDisplay = true } }

    init(control: JoystickControl, frame: NSRect) {
        self.control = control
        super.init(frame: frame)
        title = control.label
        setButtonType(.momentaryChange)
        isBordered = false
        focusRingType = .exterior
        setAccessibilityLabel(control.label)
    }

    required init?(coder: NSCoder) { return nil }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 5, dy: 5)
        let shape = NSBezierPath(
            roundedRect: rect, xRadius: control.isDirection ? 18 : 8,
            yRadius: control.isDirection ? 18 : 8)
        if control.isDirection {
            (selected ? NSColor.controlAccentColor : NSColor.white.withAlphaComponent(0.65)).setFill()
            shape.fill()
            if active {
                NSColor.systemGreen.withAlphaComponent(0.35).setFill()
                shape.fill()
            }
        } else {
            NSColor(calibratedRed: 0.40, green: 0.24, blue: 0.12, alpha: 1).setFill()
            shape.fill()
            let face = NSBezierPath(roundedRect: rect.insetBy(dx: 3, dy: 3), xRadius: 5, yRadius: 5)
            let top = NSColor(calibratedRed: 1, green: active ? 0.62 : 0.42, blue: 0.08, alpha: 1)
            let bottom = NSColor(calibratedRed: 0.91, green: active ? 0.43 : 0.24, blue: 0.02, alpha: 1)
            NSGradient(starting: top, ending: bottom)?.draw(in: face, angle: 90)
        }
        if selected || isHighlighted {
            NSColor.controlAccentColor.setStroke()
            let ring = NSBezierPath(roundedRect: rect.insetBy(dx: -3, dy: -3), xRadius: 10, yRadius: 10)
            ring.lineWidth = 3
            ring.stroke()
        }
        let glyphs = ["←", "→", "↑", "↓", "0", "1"]
        let text = glyphs[control.rawValue]
        let color: NSColor =
            control.isDirection && selected ? .white : NSColor(calibratedWhite: 0.22, alpha: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: control.isDirection ? 23 : 19, weight: .semibold),
            .foregroundColor: color,
        ]
        let size = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2),
            withAttributes: attributes)
    }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 10, yRadius: 10).fill()
    }
}

/// Draws a scalable top view inspired by the original cream, two-button joystick.
/// Hotspots remain native buttons for keyboard navigation and accessibility.
final class JoystickConfigurationView: NSView {
    var selectionChanged: ((JoystickControl) -> Void)?
    var selectedControl: JoystickControl = .up {
        didSet {
            for button in hotspots { button.selected = button.control == selectedControl }
        }
    }
    private var hotspots: [JoystickHotspot] = []
    private var stickPosition = NSPoint.zero
    private var captions: [String] = JoystickControl.allCases.map { $0.label }
    private var keyCodes: [Int]?

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        let frames = [
            NSRect(x: 163, y: 244, width: 48, height: 48),
            NSRect(x: 327, y: 244, width: 48, height: 48),
            NSRect(x: 245, y: 162, width: 48, height: 48),
            NSRect(x: 245, y: 326, width: 48, height: 48),
            NSRect(x: 57, y: 138, width: 62, height: 62),
            NSRect(x: 147, y: 57, width: 62, height: 62),
        ]
        for control in JoystickControl.allCases {
            let button = JoystickHotspot(control: control, frame: frames[control.rawValue])
            button.target = self
            button.action = #selector(selectControl(_:))
            button.selected = control == selectedControl
            addSubview(button)
            hotspots.append(button)
        }
    }

    required init?(coder: NSCoder) { return nil }

    func showAssignments(_ mapping: ControllerMapping) {
        keyCodes =
            mapping.keyboardMode == true ? (mapping.keyCodes ?? ControllerMapping.defaultKeyCodes) : nil
        captions = JoystickControl.allCases.map { control in
            if mapping.keyboardMode == true {
                let code = (mapping.keyCodes ?? ControllerMapping.defaultKeyCodes)[control.rawValue]
                return ControllerMapping.keyChoices.first(where: { $0.1 == code })?.0 ?? control.label
            }
            return control.label
        }
        for button in hotspots {
            let control = button.control
            let source =
                control.isDirection
                ? ControllerMapping.movementNames[mapping.movement]
                : ControllerMapping.buttonNames[control == .button0 ? mapping.button0 : mapping.button1]
            button.toolTip = joystickConfigurationIntl.assignmentTooltip(
                control: control.label, source: source)
            button.setAccessibilityLabel(
                joystickConfigurationIntl.assignmentAccessibilityLabel(control: control.label, source: source)
            )
            button.setAccessibilityValue(mapping.keyboardMode == true ? captions[control.rawValue] : source)
        }
        needsDisplay = true
    }

    func showInput(buttons: UInt32, x: Int32, y: Int32) {
        stickPosition = NSPoint(x: CGFloat(x) / 32767, y: CGFloat(y) / 32767)
        let active = [x < -16000, x > 16000, y < -16000, y > 16000, buttons & 1 != 0, buttons & 2 != 0]
        for button in hotspots { button.active = active[button.control.rawValue] }
        needsDisplay = true
    }

    @objc private func selectControl(_ sender: JoystickHotspot) {
        selectedControl = sender.control
        selectionChanged?(sender.control)
    }

    override func draw(_ dirtyRect: NSRect) {
        let ink = NSColor(calibratedRed: 0.32, green: 0.28, blue: 0.21, alpha: 1)
        let cable = NSBezierPath()
        cable.move(to: NSPoint(x: 115, y: 22))
        cable.curve(
            to: NSPoint(x: 112, y: 48), controlPoint1: NSPoint(x: 110, y: 29),
            controlPoint2: NSPoint(x: 112, y: 36))
        cable.lineWidth = 12
        NSColor(calibratedRed: 0.64, green: 0.59, blue: 0.45, alpha: 1).setStroke()
        cable.stroke()

        let body = NSBezierPath(
            roundedRect: NSRect(x: 38, y: 42, width: 368, height: 378),
            xRadius: 19, yRadius: 19)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
        shadow.shadowBlurRadius = 16
        shadow.shadowOffset = NSSize(width: 0, height: -6)
        shadow.set()
        NSColor(calibratedRed: 0.85, green: 0.81, blue: 0.69, alpha: 1).setFill()
        body.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGradient(colors: [
            NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.83, alpha: 1),
            NSColor(calibratedRed: 0.82, green: 0.77, blue: 0.64, alpha: 1),
        ])?
        .draw(in: body, angle: 65)
        NSColor(calibratedRed: 0.72, green: 0.66, blue: 0.51, alpha: 1).setStroke()
        body.lineWidth = 1.5
        body.stroke()

        let rim = NSBezierPath(
            roundedRect: NSRect(x: 130, y: 130, width: 276, height: 290),
            xRadius: 17, yRadius: 17)
        NSGradient(
            starting: NSColor(calibratedRed: 0.98, green: 0.95, blue: 0.83, alpha: 1),
            ending: NSColor(calibratedRed: 0.75, green: 0.68, blue: 0.50, alpha: 1))?
            .draw(in: rim, angle: 90)
        let well = NSRect(x: 150, y: 150, width: 238, height: 238)
        let center = NSPoint(x: well.midX, y: well.midY)
        let corners = [
            NSPoint(x: well.minX, y: well.minY), NSPoint(x: well.maxX, y: well.minY),
            NSPoint(x: well.maxX, y: well.maxY), NSPoint(x: well.minX, y: well.maxY),
        ]
        let colors = [
            NSColor(calibratedRed: 0.63, green: 0.51, blue: 0.29, alpha: 1),
            NSColor(calibratedRed: 0.76, green: 0.65, blue: 0.42, alpha: 1),
            NSColor(calibratedRed: 0.88, green: 0.79, blue: 0.55, alpha: 1),
            NSColor(calibratedRed: 0.71, green: 0.59, blue: 0.34, alpha: 1),
        ]
        for index in 0..<4 {
            let facet = NSBezierPath()
            facet.move(to: corners[index])
            facet.line(to: corners[(index + 1) % 4])
            facet.line(to: center)
            facet.close()
            colors[index].setFill()
            facet.fill()
        }
        let border = NSBezierPath(roundedRect: well, xRadius: 6, yRadius: 6)
        ink.withAlphaComponent(0.55).setStroke()
        border.lineWidth = 3
        border.stroke()

        let knobCenter = NSPoint(x: center.x + stickPosition.x * 25, y: center.y + stickPosition.y * 25)
        let shaft = NSBezierPath()
        shaft.move(to: center)
        shaft.line(to: knobCenter)
        shaft.lineWidth = 15
        ink.setStroke()
        shaft.stroke()
        let knob = NSBezierPath(
            ovalIn: NSRect(
                x: knobCenter.x - 26, y: knobCenter.y - 26,
                width: 52, height: 52))
        NSGradient(
            starting: NSColor(calibratedRed: 0.92, green: 0.85, blue: 0.66, alpha: 1),
            ending: NSColor(calibratedRed: 0.52, green: 0.42, blue: 0.27, alpha: 1))?
            .draw(in: knob, angle: 60)
        ink.setStroke()
        knob.lineWidth = 2
        knob.stroke()
        let cap = NSBezierPath(
            ovalIn: NSRect(
                x: knobCenter.x - 17, y: knobCenter.y - 17,
                width: 34, height: 34))
        NSColor(calibratedRed: 0.73, green: 0.64, blue: 0.46, alpha: 1).setFill()
        cap.fill()

        drawCaption("APPLE II", at: NSPoint(x: 55, y: 362), size: 11, color: ink)
        drawCaption("JOYSTICK", at: NSPoint(x: 55, y: 379), size: 8, color: ink)
        for control in JoystickControl.allCases where control.isDirection {
            let frame = hotspots[control.rawValue].frame
            let caption: String
            switch keyCodes?[control.rawValue] {
            case 55: caption = joystickConfigurationIntl.commandKeyCaption
            case 58: caption = joystickConfigurationIntl.optionKeyCaption
            default: caption = captions[control.rawValue]
            }
            drawCaption(
                caption, at: NSPoint(x: frame.midX, y: frame.maxY - 1), size: 9,
                color: ink, centered: true)
        }
    }

    private func drawCaption(
        _ text: String, at point: NSPoint, size: CGFloat, color: NSColor,
        centered: Bool = false
    ) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: size, weight: .medium), .foregroundColor: color,
        ]
        let width = text.size(withAttributes: attributes).width
        text.draw(
            at: NSPoint(x: centered ? point.x - width / 2 : point.x, y: point.y),
            withAttributes: attributes)
    }
}
