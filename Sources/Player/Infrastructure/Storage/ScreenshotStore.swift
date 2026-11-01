import Cocoa

private let playerViewIntl = PlayerViewIntl()

/// Encodes immutable game frames and publishes uniquely named screenshots without accessing views or the core.
struct ScreenshotStore {
    func save(frame: CGImage?, gameName: String, in directory: URL) throws -> URL {
        guard let image = frame,
            let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else {
            throw PlayerManifest.failure(playerViewIntl.noGameFrameIsAvailableTo)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss.SSS"
        let name =
            PlayerManifest.normalizedName(gameName)
            + " " + formatter.string(from: Date()) + " " + UUID().uuidString.prefix(6) + ".png"
        let destination = directory.appendingPathComponent(name)
        try png.write(to: destination, options: .atomic)
        return destination
    }

    func preview(at url: URL) -> CGImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return NSBitmapImageRep(data: data)?.cgImage
    }
}
