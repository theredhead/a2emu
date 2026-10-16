import Cocoa

/// A sculpted keycap whose native button retains keyboard and accessibility support.
private final class KeypadKey: NSButton {
    let code: Int
    var selected = false { didSet { needsDisplay = true } }
    var active = false { didSet { needsDisplay = true } }
    var assignmentHint = "" { didSet { needsDisplay = true } }

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

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 4, dy: 4)
        let body = NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7)
        NSColor(calibratedRed: 0.36, green: 0.36, blue: 0.31, alpha: 1).setFill()
        body.fill()
        let top = NSBezierPath(
            roundedRect: NSRect(
                x: rect.minX + 8, y: rect.minY + 10,
                width: rect.width - 14, height: rect.height - 15),
            xRadius: 5, yRadius: 5)
        let light =
            selected
            ? NSColor.controlAccentColor
            : NSColor(calibratedRed: 0.88, green: 0.88, blue: 0.80, alpha: 1)
        let dark =
            selected
            ? NSColor.controlAccentColor.blended(withFraction: 0.18, of: .black)!
            : NSColor(calibratedRed: 0.65, green: 0.66, blue: 0.58, alpha: 1)
        NSGradient(starting: light, ending: dark)?.draw(in: top, angle: 70)
        if active {
            NSColor.systemGreen.withAlphaComponent(0.6).setFill()
            top.fill()
        }
        if selected || isHighlighted {
            NSColor.controlAccentColor.setStroke()
            let ring = NSBezierPath(roundedRect: rect.insetBy(dx: -1, dy: -1), xRadius: 8, yRadius: 8)
            ring.lineWidth = 2
            ring.stroke()
        }
        let color: NSColor = selected ? .white : NSColor(calibratedWhite: 0.20, alpha: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: title.count > 2 ? 12 : 22, weight: .medium),
            .foregroundColor: color,
        ]
        let size = title.size(withAttributes: attributes)
        title.draw(
            at: NSPoint(x: top.bounds.midX - size.width / 2, y: top.bounds.midY - size.height / 2 + 3),
            withAttributes: attributes)
        let hintAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: color.withAlphaComponent(0.8),
        ]
        assignmentHint.draw(
            at: NSPoint(x: top.bounds.minX + 6, y: top.bounds.minY + 4),
            withAttributes: hintAttributes)
    }

    override func drawFocusRingMask() {
        NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 8, yRadius: 8).fill()
    }
}

/// A clickable Apple IIgs-style keypad, including the center key and two Apple-key controls.
final class KeypadConfigurationView: NSView {
    var keySelected: ((Int) -> Void)?
    var selectedKey = 87 {
        didSet { for key in keys { key.selected = key.code == selectedKey } }
    }
    private var keys: [KeypadKey] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        let rows: [[(String, Int)]] = [
            [("clear", 71), ("=", 81), ("/", 75), ("*", 67)],
            [("7", 89), ("8", 91), ("9", 92), ("−", 78)],
            [("4", 86), ("5", 87), ("6", 88), ("+", 69)],
            [("1", 83), ("2", 84), ("3", 85), ("enter", 76)],
        ]
        for (row, entries) in rows.enumerated() {
            for (column, entry) in entries.enumerated() {
                let y = CGFloat(371 - row * 75)
                let rect = NSRect(
                    x: 36 + column * 89, y: Int(y) - (entry.1 == 76 ? 75 : 0),
                    width: 82, height: entry.1 == 76 ? 144 : 69)
                addKey(title: entry.0, code: entry.1, frame: rect)
            }
        }
        addKey(title: "0", code: 82, frame: NSRect(x: 36, y: 71, width: 171, height: 69))
        addKey(title: ".", code: 65, frame: NSRect(x: 214, y: 71, width: 82, height: 69))
        addKey(title: "Open Apple", code: 55, frame: NSRect(x: 36, y: 10, width: 171, height: 44))
        addKey(title: "Closed Apple", code: 58, frame: NSRect(x: 214, y: 10, width: 171, height: 44))
    }

    required init?(coder: NSCoder) { return nil }

    private func addKey(title: String, code: Int, frame: NSRect) {
        let key = KeypadKey(title: title, code: code, frame: frame)
        key.target = self
        key.action = #selector(selectKey(_:))
        key.selected = code == selectedKey
        addSubview(key)
        keys.append(key)
    }

    @objc private func selectKey(_ sender: KeypadKey) {
        selectedKey = sender.code
        keySelected?(sender.code)
    }

    func showAssignments(_ mapping: ControllerMapping) {
        let glyphs = ["←", "→", "↑", "↓", "↖", "↗", "↙", "↘"]
        let directions = mapping.directionKeys
        let buttons = mapping.buttonKeys
        for key in keys {
            var labels = directions.indices.filter { directions[$0] == key.code }.map { glyphs[$0] }
            labels += buttons.indices.filter { buttons[$0] == key.code }.map {
                ControllerMapping.buttonNames[$0]
            }
            key.assignmentHint = labels.joined(separator: " ")
            key.toolTip =
                labels.isEmpty ? "Click to assign controller inputs" : labels.joined(separator: ", ")
            key.setAccessibilityValue(labels.isEmpty ? "Unassigned" : labels.joined(separator: ", "))
        }
    }

    func showPressedKeys(_ pressed: Set<Int32>) {
        for key in keys { key.active = pressed.contains(Int32(key.code)) }
    }

    override func draw(_ dirtyRect: NSRect) {
        let housing = NSBezierPath(
            roundedRect: NSRect(x: 22, y: 58, width: 378, height: 394),
            xRadius: 14, yRadius: 14)
        NSColor(calibratedRed: 0.77, green: 0.78, blue: 0.70, alpha: 1).setFill()
        housing.fill()
        let recess = NSBezierPath(
            roundedRect: NSRect(x: 30, y: 65, width: 362, height: 382),
            xRadius: 9, yRadius: 9)
        NSColor(calibratedWhite: 0.16, alpha: 1).setFill()
        recess.fill()
    }
}
