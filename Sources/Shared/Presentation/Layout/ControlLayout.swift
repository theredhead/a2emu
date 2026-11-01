import Cocoa

/// Aligns form labels using intrinsic text height while retaining their allocated horizontal space.
enum ControlLayout {
    static func align(_ label: NSTextField, with control: NSView) {
        let width = label.frame.width
        label.sizeToFit()
        label.frame = NSRect(
            x: label.frame.minX, y: control.frame.midY - label.frame.height / 2, width: width,
            height: label.frame.height)
    }
}
