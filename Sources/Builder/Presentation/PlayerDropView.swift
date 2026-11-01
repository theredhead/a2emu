import Cocoa

private let builderIntl = BuilderIntl()

/// Receives Finder and clipboard drag payloads and delegates import decisions to the builder.
final class PlayerDropView: NSView {
    var openFiles: (([URL]) -> Void)?
    var openImage: ((NSImage) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard()
        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty
        {
            openFiles?(urls)
            return true
        }
        if let image = NSImage(pasteboard: pasteboard) {
            openImage?(image)
            return true
        }
        return false
    }
}
