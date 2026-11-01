import Cocoa

/// Keeps the player's artwork centered when a wide accessory makes AppKit left-align its icon.
final class PlayerDiskAlert: NSAlert {
    override init() {
        super.init()
        if let url = Bundle.main.url(forResource: "PlayerIcon", withExtension: "png"),
            let image = NSImage(contentsOf: url)
        {
            icon = image
        } else {
            icon = NSImage(named: .applicationIcon)
        }
    }

    override func layout() {
        super.layout()
        guard let content = window.contentView,
            let image = content.subviews.compactMap({ $0 as? NSImageView }).first
        else { return }
        image.setFrameOrigin(NSPoint(x: (content.bounds.width - image.frame.width) / 2, y: image.frame.minY))
    }
}
