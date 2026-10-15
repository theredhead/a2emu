import Cocoa

struct IconEncoder {
    /// Writes PNG-backed ICNS sizes atomically; throws if image decoding or encoding fails.
    static func writeICNS(png: Data, destination: URL) throws {
        guard let image = NSImage(data: png) else {
            throw PlayerManifest.failure("The icon image is invalid.")
        }
        // ICNS supports PNG representations directly, so export needs no external icon compiler.
        var archive = Data("icns".utf8)
        var chunks = Data()

        func integer(_ value: UInt32) -> Data {
            var big = value.bigEndian
            return withUnsafeBytes(of: &big) { Data($0) }
        }
        for (type, size) in [
            ("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128), ("ic08", 256), ("ic09", 512),
            ("ic10", 1024),
        ] {
            guard
                let bitmap = NSBitmapImageRep(
                    bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                    bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap)
            else {
                throw PlayerManifest.failure("Could not encode icon.")
            }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = context
            image.draw(
                in: NSRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
            guard let bytes = bitmap.representation(using: .png, properties: [:]) else {
                throw PlayerManifest.failure("Could not encode icon.")
            }
            chunks.append(Data(type.utf8))
            chunks.append(integer(UInt32(bytes.count + 8)))
            chunks.append(bytes)
        }
        archive.append(integer(UInt32(chunks.count + 8)))
        archive.append(chunks)
        try archive.write(to: destination, options: .atomic)
    }
}
