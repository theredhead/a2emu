import Cocoa

/// Decorative artwork fitted proportionally and anchored to the window's bottom edge.
final class BuilderArtworkView: NSView {
    private let artwork = Bundle.main.url(forResource: "BuilderIcon", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let artwork = artwork else { return }

        let scale = min(bounds.width / artwork.size.width, bounds.height / artwork.size.height)
        let size = NSSize(width: artwork.size.width * scale, height: artwork.size.height * scale)
        artwork.draw(
            in: NSRect(x: bounds.maxX - size.width, y: bounds.minY, width: size.width, height: size.height),
            from: .zero, operation: .sourceOver, fraction: 1)
    }
}
