import Cocoa
import WebKit
import UniformTypeIdentifiers

final class SquareCropView: NSView {
    var image: NSImage? { didSet { zoom = 1; offset = .zero; needsDisplay = true } }
    var zoom: CGFloat = 1 { didSet { constrain(); needsDisplay = true } }
    var offset = CGPoint.zero
    private var dragStart = CGPoint.zero
    private var originalOffset = CGPoint.zero
    override var isFlipped: Bool { false }
    private var imageRect: CGRect {
        guard let image = image, image.size.width > 0, image.size.height > 0 else { return .zero }
        let scale = max(bounds.width / image.size.width, bounds.height / image.size.height) * zoom
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(x: (bounds.width - size.width) / 2 + offset.x, y: (bounds.height - size.height) / 2 + offset.y, width: size.width, height: size.height)
    }
    private func constrain() {
        let rect = imageRect
        offset.x = min(max(offset.x, -(rect.width-bounds.width)/2), (rect.width-bounds.width)/2)
        offset.y = min(max(offset.y, -(rect.height-bounds.height)/2), (rect.height-bounds.height)/2)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(rect: bounds).addClip()
        NSColor.black.setFill(); bounds.fill()
        guard let image = image else {
            let text = "Select an image to crop"
            text.draw(at: CGPoint(x: 35, y: bounds.midY), withAttributes: [.foregroundColor: NSColor.secondaryLabelColor, .font: NSFont.systemFont(ofSize: 15)])
            return
        }
        image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1)
    }
    override func mouseDown(with event: NSEvent) { dragStart = convert(event.locationInWindow, from: nil); originalOffset = offset }
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        offset = CGPoint(x: originalOffset.x + point.x - dragStart.x, y: originalOffset.y + point.y - dragStart.y)
        constrain(); needsDisplay = true
    }
    func png() -> Data? {
        guard let image = image, let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        let rect = imageRect
        let factor = 1024 / bounds.width
        image.draw(in: CGRect(x: rect.minX * factor, y: rect.minY * factor, width: rect.width * factor, height: rect.height * factor), from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
    }
}

final class IconPicker: NSObject, WKScriptMessageHandler, NSWindowDelegate {
    private var window: NSWindow!
    private var browser: WKWebView!
    private let crop = SquareCropView(frame: NSRect(x: 682, y: 174, width: 300, height: 300))
    private let query = NSTextField(string: "")
    private let status = NSTextField(labelWithString: "Click an image result, or choose a local image.")
    private var zoomSlider: NSSlider!
    private var requestID = 0
    private var completion: ((Data) -> Void)?
    func show(diskName: String, completion: @escaping (Data) -> Void) {
        self.completion = completion
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1010, height: 640), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Choose Player Icon"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let root = window.contentView!
        query.stringValue = "apple ][ " + diskName
        query.frame = NSRect(x: 20, y: 592, width: 520, height: 28); root.addSubview(query)
        let search = NSButton(title: "Search", target: self, action: #selector(searchImages(_:)))
        search.frame = NSRect(x: 548, y: 590, width: 100, height: 32); search.bezelStyle = .rounded; root.addSubview(search)
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.add(self, name: "iconImage")
        let script = """
        document.addEventListener('click', function(event) {
            const image = event.target.closest('img');
            if (!image || image.naturalWidth < 80 || image.naturalHeight < 80) return;
            window.webkit.messageHandlers.iconImage.postMessage(image.currentSrc || image.src);
        }, true);
        """
        configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        browser = WKWebView(frame: NSRect(x: 20, y: 20, width: 628, height: 554), configuration: configuration)
        root.addSubview(browser); root.addSubview(crop)
        let instruction = NSTextField(labelWithString: "Drag to position the square crop.")
        instruction.frame = NSRect(x: 682, y: 491, width: 308, height: 32); root.addSubview(instruction)
        let zoom = NSSlider(value: 1, minValue: 1, maxValue: 4, target: self, action: #selector(zoomChanged(_:)))
        zoomSlider = zoom
        zoom.frame = NSRect(x: 682, y: 133, width: 300, height: 24); root.addSubview(zoom)
        let local = NSButton(title: "Choose Local Image…", target: self, action: #selector(chooseLocal(_:)))
        local.frame = NSRect(x: 682, y: 89, width: 300, height: 32); local.bezelStyle = .rounded; root.addSubview(local)
        let use = NSButton(title: "Use This Crop", target: self, action: #selector(useCrop(_:)))
        use.frame = NSRect(x: 682, y: 46, width: 300, height: 32); use.bezelStyle = .rounded; root.addSubview(use)
        status.frame = NSRect(x: 682, y: 537, width: 300, height: 40); status.lineBreakMode = .byWordWrapping; root.addSubview(status)
        window.center(); window.makeKeyAndOrderFront(nil)
        searchImages(nil)
    }
    @objc private func searchImages(_ sender: Any?) {
        var url = URLComponents(string: "https://duckduckgo.com/")!
        url.queryItems = [URLQueryItem(name: "q", value: query.stringValue), URLQueryItem(name: "iax", value: "images"), URLQueryItem(name: "ia", value: "images")]
        browser.load(URLRequest(url: url.url!))
    }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let value = message.body as? String else { return }
        requestID += 1; let selectedID = requestID
        if value.hasPrefix("data:image"), let part = value.components(separatedBy: ",").last, let data = Data(base64Encoded: part), let image = NSImage(data: data) {
            crop.image = image; zoomSlider.doubleValue = 1; status.stringValue = "Drag and zoom, then use this crop."; return
        }
        guard let url = URL(string: value), ["https", "http"].contains(url.scheme ?? "") else { return }
        status.stringValue = "Loading selected image…"
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self, self.requestID == selectedID else { return }
                if let data = data, data.count <= 30 * 1024 * 1024, let image = NSImage(data: data) {
                    self.crop.image = image; self.zoomSlider.doubleValue = 1; self.status.stringValue = "Drag and zoom, then use this crop."
                } else { self.status.stringValue = "Could not load that image. Try another result or a local file." }
            }
        }.resume()
    }
    @objc private func zoomChanged(_ sender: NSSlider) { crop.zoom = CGFloat(sender.doubleValue) }
    @objc private func chooseLocal(_ sender: Any?) {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.image]; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) else { return }
        requestID += 1; crop.image = image; zoomSlider.doubleValue = 1; status.stringValue = "Drag and zoom, then use this crop."
    }
    @objc private func useCrop(_ sender: Any?) {
        guard let data = crop.png() else { status.stringValue = "Choose an image first."; return }
        completion?(data); window.close()
    }
    func windowWillClose(_ notification: Notification) {
        requestID += 1
        browser.configuration.userContentController.removeScriptMessageHandler(forName: "iconImage")
        completion = nil
    }
}
