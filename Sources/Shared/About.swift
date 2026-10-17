import Cocoa

private let aboutIntl = AboutIntl()
private let commonIntl = CommonIntl()

final class AppAbout: NSObject, NSWindowDelegate {
    var creditsVisibilityChanged: ((Bool) -> Void)?
    private var creditsWindow: NSWindow?

    func show() {
        let panel = NSAlert()
        panel.messageText = PlayerManifest.displayName
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        panel.informativeText =
            aboutIntl.versionInfo(version: version)
        // Supply the original image, avoiding the system's legacy icon container.
        if let url = Bundle.main.url(forResource: "PlayerIcon", withExtension: "png")
            ?? Bundle.main.url(forResource: "BuilderIcon", withExtension: "png")
        {
            panel.icon = NSImage(contentsOf: url)
        }
        panel.addButton(withTitle: commonIntl.close)
        panel.addButton(withTitle: aboutIntl.more)
        if panel.runModal() == .alertSecondButtonReturn {
            showCredits()
        }
    }

    func showCredits() {
        creditsVisibilityChanged?(true)
        if let window = creditsWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 490),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.delegate = self
        window.title = aboutIntl.thanksTo
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
            var attributes: [NSAttributedString.Key: Any] = [
                .font: bold ? NSFont.boldSystemFont(ofSize: 16) : NSFont.systemFont(ofSize: 13),
                .foregroundColor: NSColor.labelColor,
            ]
            if let link = link {
                attributes[.link] = link
            }
            body.append(NSAttributedString(string: string + "\n\n", attributes: attributes))
        }
        paragraph(aboutIntl.thanksTo, bold: true)
        paragraph("KEGS", bold: true)
        paragraph(aboutIntl.appleIigsEmulationByKentDickey)
        paragraph(aboutIntl.kegsProjectAndSource, link: URL(string: "https://kegs.sourceforge.net/"))
        paragraph("GSplus", bold: true)
        paragraph(aboutIntl.crossPlatformWorkByDagenBrock)
        paragraph(aboutIntl.gsplusSourceOnGithub, link: URL(string: "https://github.com/digarok/gsplus"))
        paragraph(aboutIntl.appleIigsPlayerBuilderAndApple, bold: true)
        paragraph(
            aboutIntl.integrationCredit
        )
        paragraph(aboutIntl.a2emuSourceOnGithub, link: URL(string: "https://github.com/theredhead/a2emu"))
        paragraph(aboutIntl.license, bold: true)
        paragraph(
            aboutIntl.licenseExplanation
        )
        if let license = Bundle.main.url(forResource: "GSplus-LICENSE", withExtension: "txt")
            ?? Bundle.main.url(forResource: "LICENSE", withExtension: "txt"),
            let content = try? String(contentsOf: license, encoding: .utf8)
        {
            paragraph(content)
        }
        text.textStorage?.setAttributedString(body)
        scroll.documentView = text
        root.addSubview(scroll)
        let save = NSButton(title: aboutIntl.viewOnGithub, target: self, action: #selector(openSource(_:)))
        save.bezelStyle = .rounded
        save.frame = NSRect(x: 24, y: 24, width: 180, height: 32)
        root.addSubview(save)
        window.contentView = root
        creditsWindow = window
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        creditsVisibilityChanged?(false)
    }

    @objc private func openSource(_ sender: Any?) {
        if let url = URL(string: "https://github.com/theredhead/a2emu") {
            NSWorkspace.shared.open(url)
        }
    }
}
