import Cocoa

/// A controller symbol and its category color, kept separate from the keyboard legend.
struct KeyAssignmentBadge {
    let input: String

    var color: NSColor {
        switch input {
        case "A": return .systemGreen
        case "B": return .systemRed
        case "X": return .systemBlue
        case "Y": return .systemYellow
        default:
            if input.hasPrefix("D") { return .systemOrange }
            if input.hasPrefix("R") { return .systemPurple }
            if input.hasPrefix("L") { return .systemBlue }
            return .systemGray
        }
    }

    var symbol: String {
        if input == "Start" { return "▶" }
        if input == "Select" { return "⧉" }
        return input
    }
}

/// A flat keycap with controller badges overlapping its top-right corner.
final class KeypadKey: NSButton {
    var compact = false
    var returnNotch: CGFloat?
    override var isFlipped: Bool { return returnNotch == nil ? super.isFlipped : false }
    let code: Int
    var selected = false { didSet { needsDisplay = true } }
    var active = false { didSet { needsDisplay = true } }
    var assignmentBadges: [KeyAssignmentBadge] = [] { didSet { needsDisplay = true } }

    init(title: String, code: Int, frame: NSRect) {
        self.code = code
        super.init(frame: frame)
        self.title = title
        setButtonType(.momentaryChange)
        isBordered = false
        focusRingType = .exterior
        setAccessibilityLabel(title)
    }

    required init?(coder: NSCoder) { return nil }

    private func keyShape(in rect: NSRect, radius: CGFloat = 5) -> NSBezierPath {
        guard let notch = returnNotch else {
            return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        }
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX + notch, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX + notch, y: rect.minY + rect.height / 2))
        path.line(to: NSPoint(x: rect.minX, y: rect.minY + rect.height / 2))
        path.close()
        return path
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if returnNotch != nil && !keyShape(in: bounds).contains(local) { return nil }
        return super.hitTest(point)
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 4, dy: 4)
        let top = keyShape(in: rect)
        let faceColor =
            selected
            ? NSColor.controlAccentColor : NSColor(calibratedRed: 0.88, green: 0.88, blue: 0.80, alpha: 1)
        faceColor.setFill()
        top.fill()
        NSColor(calibratedWhite: 0.35, alpha: 0.35).setStroke()
        top.lineWidth = 1
        top.stroke()
        if active {
            NSColor.systemGreen.withAlphaComponent(0.6).setFill()
            top.fill()
        }
        if selected || isHighlighted {
            NSColor.controlAccentColor.setStroke()
            let ring = keyShape(in: rect.insetBy(dx: -1, dy: -1), radius: 8)
            ring.lineWidth = 2
            ring.stroke()
        }
        let color: NSColor = selected ? .white : NSColor(calibratedWhite: 0.20, alpha: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(
                ofSize: compact
                    ? (title.count > 2 ? (bounds.width < 50 ? 9 : 11) : 16) : (title.count > 2 ? 14 : 26),
                weight: .medium),
            .foregroundColor: color,
        ]
        let size = title.size(withAttributes: attributes)
        title.draw(
            at: NSPoint(
                x: top.bounds.midX - size.width / 2,
                y: (returnNotch == nil ? top.bounds.midY : top.bounds.minY + 16) - size.height / 2),
            withAttributes: attributes)
        drawAssignmentBadges()
    }

    private func drawAssignmentBadges() {
        let visible = Array(assignmentBadges.prefix(2))
        for (index, badge) in visible.enumerated().reversed() {
            let diameter: CGFloat = 18
            let rect = NSRect(
                x: bounds.maxX - diameter - CGFloat(index) * 15,
                y: isFlipped ? 0 : bounds.maxY - diameter, width: diameter, height: diameter)
            let circle = NSBezierPath(ovalIn: rect)
            badge.color.setFill()
            circle.fill()
            NSColor(calibratedWhite: 0.98, alpha: 1).setStroke()
            circle.lineWidth = 1.5
            circle.stroke()
            let more = index == 1 && assignmentBadges.count > 2
            let symbol = more ? "+\(assignmentBadges.count - 1)" : badge.symbol
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: symbol.count > 1 ? 8 : 11, weight: .bold),
                .foregroundColor: badge.input == "Y" ? NSColor.black : NSColor.white,
            ]
            let size = symbol.size(withAttributes: attributes)
            symbol.draw(
                at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                withAttributes: attributes)
        }
    }

    override func drawFocusRingMask() {
        keyShape(in: bounds.insetBy(dx: 3, dy: 3), radius: 8).fill()
    }
}
