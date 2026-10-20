import Cocoa

@main struct DutchLayoutTests {
    static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        precondition(Bundle.main.preferredLocalizations.first == "nl")
        precondition(CommonIntl().cancel == "Annuleer")
        var failures: [String] = []
        func inspect(_ view: NSView) {
            guard !view.isHidden else { return }
            if view is JoystickConfigurationView {
                // Hotspot titles are accessibility text; the illustration draws arrows instead.
                for control in JoystickControl.allCases where control.isDirection {
                    let size = control.label.size(withAttributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 9, weight: .medium)
                    ])
                    precondition(size.width <= 48, "Drawn joystick caption must fit")
                }
                return
            }
            if let button = view as? NSButton, !(button is NSPopUpButton), !button.title.isEmpty,
                button.imagePosition != .imageOnly
            {
                let needed = button.intrinsicContentSize.width
                if needed > button.frame.width + 2 {
                    failures.append(
                        "Button: \(button.title) needs \(Int(needed)), has \(Int(button.frame.width))")
                }
            } else if let field = view as? NSTextField, !field.isEditable, !field.stringValue.isEmpty {
                let cell = field.cell!
                if cell.wraps {
                    let needed = cell.cellSize(
                        forBounds: NSRect(x: 0, y: 0, width: field.frame.width, height: 1000)
                    ).height
                    if needed > field.frame.height + 2 {
                        failures.append(
                            "Wrapped label: \(field.stringValue) needs height \(Int(needed)), has \(Int(field.frame.height))"
                        )
                    }
                } else {
                    let needed = cell.cellSize.width
                    if needed > field.frame.width + 2 {
                        failures.append(
                            "Label: \(field.stringValue) needs \(Int(needed)), has \(Int(field.frame.width))")
                    }
                }
            }
            for child in view.subviews { inspect(child) }
        }
        let builder = Builder()
        builder.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification))
        let snapshotButton = builder.snapshotLabel.superview!.subviews.compactMap { $0 as? NSButton }.first {
            $0.action == #selector(Builder.chooseSnapshot(_:))
        }!
        precondition(abs(builder.snapshotLabel.frame.midY - snapshotButton.frame.midY) < 0.5)
        builder.selectDisks([URL(fileURLWithPath: "/nonexistent/HyperCard.hdv")])
        for (field, choice) in zip(builder.diskNameFields, builder.mountChoices) {
            precondition(abs(field.frame.midY - choice.frame.midY) < 0.5)
            precondition(abs(field.frame.height - field.intrinsicContentSize.height) < 0.5)
        }
        inspect(builder.window.contentView!)
        let panel = ControllerMappingPanel()
        panel.build()
        panel.refreshControllers(force: true)
        panel.refresh()
        inspect(panel.window.contentView!)
        panel.draft = ControllerMapping.defaults
        panel.draft.keyboardMode = true
        panel.draft.prepareKeyboardBindings()
        panel.draft.keyboardLayout = true
        panel.refresh()
        inspect(panel.window.contentView!)
        FileHandle.standardError.write(Data((failures.joined(separator: "\n") + "\n").utf8))
        precondition(failures.isEmpty, "Dutch UI text must fit its controls")
        print("PASS system Dutch selection and builder, joystick, and keyboard/mouse label bounds")
    }
}
