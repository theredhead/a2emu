import Cocoa

/// Owns the bitmap and borrowed pixel pointers passed to the C renderer. Access only on the main thread.
/// Callers receive immutable frames; they never retain or free the renderer's memory.
final class EmulatorFramebuffer {
    private let context: CGContext
    private let pixels: UnsafeMutablePointer<UInt32>

    init(context: CGContext) {
        self.context = context
        self.pixels = context.data!.bindMemory(to: UInt32.self, capacity: context.width * context.height)
    }

    convenience init(width: Int, height: Int) {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGDisplayCopyColorSpace(CGMainDisplayID()),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.data!.initializeMemory(as: UInt32.self, repeating: 0, count: width * height)
        self.init(context: context)
    }

    var frame: CGImage? { return context.makeImage() }

    func displayPreview(_ image: CGImage) {
        context.draw(image, in: CGRect(x: 0, y: 0, width: context.width, height: context.height))
    }

    func update(from image: EmulatorCore.Image) -> Bool {
        var changed = false
        var rect = EmulatorCore.ChangeRect(x: 0, y: 0, width: 0, height: 0)
        for index in 0..<EmulatorCore.maximumChangeRects {
            if EmulatorCore.drawImageChanges(
                into: pixels, image: image,
                pixelsPerRow: Int32(context.width), rect: &rect, index: Int32(index)) == 0
            {
                break
            }
            changed = true
        }
        return changed
    }

    static func drawDirect(_ image: EmulatorCore.Image, in context: CGContext) {
        guard let data = context.data else { return }

        var rect = EmulatorCore.ChangeRect(
            x: 0, y: 0, width: Int32(context.width), height: Int32(context.height))
        EmulatorCore.updateImageScale(
            image, width: Int32(context.width), height: Int32(context.height), force: false)
        EmulatorCore.drawScaledImage(
            into: data, image: image, pixelsPerRow: Int32(context.bytesPerRow / 4), rect: &rect)
        EmulatorCore.finishDrawing(image)
    }
}
