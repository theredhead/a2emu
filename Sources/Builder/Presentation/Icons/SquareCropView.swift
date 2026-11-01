import Cocoa
import UniformTypeIdentifiers
import WebKit

private let iconPickerIntl = IconPickerIntl()

/// Displays a draggable square crop and renders it as a 1024-pixel PNG.
final class SquareCropView: NSView {
    var image: NSImage? {
        didSet {
            zoom = 1
            offset = .zero
            needsDisplay = true
        }
    }

    var zoom: CGFloat = 1 {
        didSet {
            constrain()
            needsDisplay = true
        }
    }

    var offset = CGPoint.zero
    private var dragStart = CGPoint.zero
    private var originalOffset = CGPoint.zero

    override var isFlipped: Bool { false }

    private var imageRect: CGRect {
        guard let image = image, image.size.width > 0, image.size.height > 0 else {
            return .zero
        }

        let scale = max(bounds.width / image.size.width, bounds.height / image.size.height) * zoom
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(
            x: (bounds.width - size.width) / 2 + offset.x, y: (bounds.height - size.height) / 2 + offset.y,
            width: size.width, height: size.height)
    }

    private func constrain() {
        let rect = imageRect
        offset.x = min(max(offset.x, -(rect.width - bounds.width) / 2), (rect.width - bounds.width) / 2)
        offset.y = min(max(offset.y, -(rect.height - bounds.height) / 2), (rect.height - bounds.height) / 2)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect: bounds).addClip()
        NSColor.black.setFill()
        bounds.fill()
        guard let image = image else {
            let text = iconPickerIntl.selectAnImageToCrop
            text.draw(
                at: CGPoint(x: 35, y: bounds.midY),
                withAttributes: [
                    .foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: 15),
                ])
            return
        }
        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        originalOffset = offset
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        offset = CGPoint(
            x: originalOffset.x + point.x - dragStart.x, y: originalOffset.y + point.y - dragStart.y)
        constrain()
        needsDisplay = true
    }

    /// Renders the current crop, returning nil if no image or bitmap context is available.
    func png() -> Data? {
        guard let image = image,
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else {
            return nil
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let rect = imageRect
        let factor = 1024 / bounds.width
        image.draw(
            in: CGRect(
                x: rect.minX * factor, y: rect.minY * factor, width: rect.width * factor,
                height: rect.height * factor), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
    }
}
