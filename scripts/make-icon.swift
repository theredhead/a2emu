import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Converts supplied artwork to square PNG icon representations, preserving proportions and transparency.
@main struct MakeIcon {
    static func main() throws {
        let source = URL(fileURLWithPath: CommandLine.arguments[1])
        let destination = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else { throw failure("Cannot read icon artwork") }
        for size in [16, 32, 128, 256, 512] {
            for multiplier in [1, 2] {
                let pixels = size * multiplier
                guard
                    let context = CGContext(
                        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                else { throw failure("Cannot create icon canvas") }

                let scale = min(
                    CGFloat(pixels) / CGFloat(image.width), CGFloat(pixels) / CGFloat(image.height))
                let width = CGFloat(image.width) * scale
                let height = CGFloat(image.height) * scale
                context.interpolationQuality = .high
                context.draw(
                    image,
                    in: CGRect(
                        x: (CGFloat(pixels) - width) / 2, y: (CGFloat(pixels) - height) / 2,
                        width: width, height: height))
                let suffix = multiplier == 2 ? "@2x" : ""
                let output = destination.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
                guard let rendered = context.makeImage(),
                    let writer = CGImageDestinationCreateWithURL(
                        output as CFURL, UTType.png.identifier as CFString, 1, nil)
                else { throw failure("Cannot encode icon representation") }
                CGImageDestinationAddImage(writer, rendered, nil)
                guard CGImageDestinationFinalize(writer) else {
                    throw failure("Cannot write icon representation")
                }
            }
        }
    }

    private static func failure(_ message: String) -> NSError {
        return NSError(domain: "MakeIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
