import Cocoa

final class PlayerAbout {
    private var creditsWindow: NSWindow?
    func show() {
        let panel = NSAlert()
        panel.messageText = PlayerManifest.displayName
        panel.informativeText = "Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")\n\nBuilt with KEGS and GSplus."
        // Supply the original image, avoiding the system's legacy icon container.
        if let url = Bundle.main.url(forResource: "PlayerIcon", withExtension: "png") {
            panel.icon = NSImage(contentsOf: url)
        }
        panel.addButton(withTitle: "Close")
        panel.addButton(withTitle: "More…")
        if panel.runModal() == .alertSecondButtonReturn { showCredits() }
    }
    func showCredits() {
        if let window = creditsWindow { window.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 490), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "Thanks to…"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 480, height: 360)
        let root = NSView(frame: window.contentView!.bounds)
        root.autoresizingMask = [.width, .height]
        let scroll = NSScrollView(frame: NSRect(x: 24, y: 78, width: 552, height: 388))
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let text = NSTextView(frame: scroll.bounds)
        text.isEditable = false
        text.isSelectable = true
        text.drawsBackground = false
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        let body = NSMutableAttributedString()
        func paragraph(_ string: String, bold: Bool = false, link: URL? = nil) {
            var attributes: [NSAttributedString.Key: Any] = [.font: bold ? NSFont.boldSystemFont(ofSize: 16) : NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor]
            if let link = link { attributes[.link] = link }
            body.append(NSAttributedString(string: string + "\n\n", attributes: attributes))
        }
        paragraph("Thanks to…", bold: true)
        paragraph("KEGS", bold: true)
        paragraph("Apple IIgs emulation by Kent Dickey.")
        paragraph("KEGS project and source", link: URL(string: "https://kegs.sourceforge.net/"))
        paragraph("GSplus", bold: true)
        paragraph("Cross-platform work by Dagen Brock and GSplus contributors, building on KEGS.")
        paragraph("GSplus source on GitHub", link: URL(string: "https://github.com/digarok/gsplus"))
        paragraph("Apple II Player", bold: true)
        paragraph("Swift player integration by theredhead. The exact source used for this build, including the adapted Swift frontend, emulator sources, assets and build scripts, is embedded in this app. Save it using the button below.")
        paragraph("License", bold: true)
        paragraph("The player and emulator components are distributed under GNU GPL version 3. Original copyright notices and component licenses are preserved in the source archive. ROM firmware and software you run are separate from the player.")
        if let license = Bundle.main.url(forResource: "GSplus-LICENSE", withExtension: "txt"), let content = try? String(contentsOf: license, encoding: .utf8) {
            paragraph(content)
        }
        text.textStorage?.setAttributedString(body)
        scroll.documentView = text
        root.addSubview(scroll)
        let save = NSButton(title: "Save Source Code…", target: self, action: #selector(saveSource(_:)))
        save.bezelStyle = .rounded
        save.frame = NSRect(x: 24, y: 24, width: 180, height: 32)
        root.addSubview(save)
        window.contentView = root
        creditsWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
    }
    @objc private func saveSource(_ sender: Any?) {
        guard let source = Bundle.main.url(forResource: "Player-Source", withExtension: "zip") else { return }
        let panel = NSSavePanel()
        panel.title = "Save Player Source Code"
        panel.nameFieldStringValue = "Apple-II-Player-Source.zip"
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do { try Data(contentsOf: source).write(to: destination, options: .atomic) }
        catch {
            let alert = NSAlert()
            alert.messageText = "Could not save source code"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
