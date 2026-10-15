import Cocoa

final class PlayerDropView: NSView {
    var openPlayer: ((URL) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard
            let urls = sender.draggingPasteboard().readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], urls.count == 1
        else {
            return false
        }
        openPlayer?(urls[0])
        return true
    }
}

@main final class Builder: NSObject, NSApplicationDelegate {
    let aboutPanel = AppAbout()

    @objc func showAbout(_ sender: Any?) {
        aboutPanel.show()
    }

    var window: NSWindow!
    var disks: [URL] = []
    var iconData: Data?
    var iconPicker: IconPicker?
    let iconPreview = NSImageView(frame: NSRect(x: 506, y: 86, width: 84, height: 84))
    let heading = NSTextField(labelWithString: "Create a standalone Apple II player")
    let appName = NSTextField(string: "")
    let mountList = NSScrollView(frame: NSRect(x: 28, y: 198, width: 564, height: 180))
    var listedDrives: [DriveAddress] = []
    var driveCounts: [NSPopUpButton] = []
    var configuredDrives: [DriveAddress] {
        zip([6, 5, 7], driveCounts).flatMap { slot, count in
            (0..<count.indexOfSelectedItem).map { DriveAddress(slot: slot, drive: $0) }
        }
    }

    var diskNameFields: [NSTextField] = []
    var mountChoices: [NSPopUpButton] = []
    let summary = NSTextField(labelWithString: "Choose disk images to package.")
    let fullScreen = NSButton(checkboxWithTitle: "Start in full screen", target: nil, action: nil)
    let speed = NSPopUpButton(frame: .zero)
    let slot = NSPopUpButton(frame: .zero)
    var editingPlayer: URL?
    var pendingPlayer: URL?
    let exportButton = NSButton(title: "Create Player…", target: nil, action: nil)
    var delegateLifetime: Builder?

    static func main() {
        if CommandLine.arguments.contains("--export") {
            do {
                let args = CommandLine.arguments

                func value(_ flag: String) -> String {
                    args[args.firstIndex(of: flag)! + 1]
                }
                try PlayerExporter.export(
                    disks: [URL(fileURLWithPath: value("--export"))], slot: Int(value("--boot-slot"))!,
                    template: URL(fileURLWithPath: value("--template")),
                    destination: URL(fileURLWithPath: value("--output")),
                    displayName: args.contains("--name") ? value("--name") : nil)
                print("Player exported.")
                return
            } catch {
                fputs("\(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }

        let delegate = Builder()
        delegate.delegateLifetime = delegate
        NSApplication.shared.delegate = delegate
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let app = NSMenu(title: "Apple II Wrapper Builder")
        let about = app.addItem(
            withTitle: "About Apple II Wrapper Builder", action: #selector(showAbout(_:)), keyEquivalent: "")
        about.target = self
        app.addItem(NSMenuItem.separator())
        app.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = app
        menu.addItem(appItem)
        NSApp.mainMenu = menu
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        for (title, action, key) in [
            ("New Player", #selector(newPlayer(_:)), "n"),
            ("Open Player…", #selector(openPlayerPanel(_:)), "o"),
        ] {
            let item = fileMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
            item.target = self
        }
        fileItem.submenu = fileMenu
        menu.addItem(fileItem)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 710),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Apple II Wrapper Builder"
        let root = PlayerDropView(frame: window.contentView!.bounds)
        root.registerForDraggedTypes([.fileURL])
        root.openPlayer = { [weak self] in self?.loadPlayer($0) }
        window.contentView = root
        let title = heading
        title.font = .boldSystemFont(ofSize: 20)
        title.frame = NSRect(x: 28, y: 650, width: 560, height: 32)
        root.addSubview(title)
        summary.frame = NSRect(x: 212, y: 608, width: 380, height: 32)
        summary.lineBreakMode = .byWordWrapping
        root.addSubview(summary)
        let choose = NSButton(title: "Choose Disks…", target: self, action: #selector(chooseDisks(_:)))
        choose.frame = NSRect(x: 28, y: 608, width: 160, height: 32)
        choose.bezelStyle = .rounded
        root.addSubview(choose)
        let label = NSTextField(labelWithString: "Start up from:")
        label.frame = NSRect(x: 28, y: 511, width: 110, height: 24)
        root.addSubview(label)
        slot.frame = NSRect(x: 140, y: 508, width: 452, height: 28)
        slot.addItems(withTitles: [
            "Slot 6 — 5.25-inch floppy", "Slot 5 — 3.5-inch floppy", "Slot 7 — hard disk / SmartPort",
        ])
        root.addSubview(slot)
        let speedLabel = NSTextField(labelWithString: "Initial speed:")
        speedLabel.frame = NSRect(x: 28, y: 465, width: 110, height: 24)
        root.addSubview(speedLabel)
        speed.frame = NSRect(x: 140, y: 462, width: 452, height: 28)
        speed.addItems(withTitles: EmulationSpeed.allCases.map { $0.label })
        root.addSubview(speed)
        align(label, with: slot)
        align(speedLabel, with: speed)
        slot.target = self
        slot.action = #selector(startupChanged(_:))
        let nameLabel = NSTextField(labelWithString: "App name:")
        nameLabel.frame = NSRect(x: 28, y: 558, width: 110, height: 24)
        root.addSubview(nameLabel)
        appName.frame = NSRect(x: 140, y: 555, width: 452, height: 28)
        appName.placeholderString = "Name of the exported app"
        root.addSubview(appName)
        align(nameLabel, with: appName)
        let mounted = NSTextField(labelWithString: "Disk names and initial drives")
        mounted.frame = NSRect(x: 28, y: 379, width: 564, height: 24)
        root.addSubview(mounted)
        for (index, title) in ["5.25-inch", "3.5-inch", "SmartPort"].enumerated() {
            let x = CGFloat(28 + index * 190)
            let label = NSTextField(labelWithString: title + " drives:")
            label.frame = NSRect(x: x, y: 410, width: 110, height: 24)
            root.addSubview(label)
            let count = NSPopUpButton(frame: NSRect(x: x + 108, y: 407, width: 70, height: 28))
            count.addItems(withTitles: (0...(index == 2 ? 16 : 2)).map { String($0) })
            count.selectItem(at: index == 0 ? 1 : 0)
            count.target = self
            count.action = #selector(drivesChanged(_:))
            root.addSubview(count)
            driveCounts.append(count)
            align(label, with: count)
        }
        mountList.hasVerticalScroller = true
        mountList.borderType = .bezelBorder
        root.addSubview(mountList)
        let help = NSTextField(
            wrappingLabelWithString:
                "Leave extra images unmounted; swap them into a drive later through Emulation → Disks.")
        help.frame = NSRect(x: 28, y: 146, width: 450, height: 40)
        root.addSubview(help)
        root.addSubview(iconPreview)
        let icon = NSButton(title: "Choose Player Icon…", target: self, action: #selector(chooseIcon(_:)))
        icon.frame = NSRect(x: 28, y: 102, width: 210, height: 32)
        icon.bezelStyle = .rounded
        root.addSubview(icon)
        fullScreen.frame = NSRect(x: 28, y: 63, width: 280, height: 24)
        root.addSubview(fullScreen)
        let export = exportButton
        export.target = self
        export.action = #selector(createPlayer(_:))
        export.frame = NSRect(x: 402, y: 25, width: 190, height: 34)
        export.bezelStyle = .rounded
        root.addSubview(export)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let pending = pendingPlayer {
            pendingPlayer = nil
            loadPlayer(pending)
        }
    }

    func align(_ label: NSTextField, with control: NSView) {
        let width = label.frame.width
        label.sizeToFit()
        label.frame = NSRect(
            x: label.frame.minX, y: control.frame.midY - label.frame.height / 2, width: width,
            height: label.frame.height)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        true
    }

    @objc func chooseDisks(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["woz", "dsk", "do", "po", "2mg", "hdv", "nib"]
        guard panel.runModal() == .OK else {
            return
        }

        let previousDefault = disks.first?.deletingPathExtension().lastPathComponent
        diskNameFields = []
        mountChoices = []
        disks = panel.urls
        summary.stringValue = "\(disks.count) disk image\(disks.count == 1 ? "" : "s") selected"
        if appName.stringValue.isEmpty || appName.stringValue == previousDefault {
            appName.stringValue = disks[0].deletingPathExtension().lastPathComponent
        }
        rebuildMounts()
    }

    @objc func startupChanged(_ sender: Any?) {
        mountChoices = []
        for (index, count) in driveCounts.enumerated() {
            count.selectItem(at: index == slot.indexOfSelectedItem ? 1 : 0)
        }
        rebuildMounts()
    }

    @objc func drivesChanged(_ sender: Any?) {
        rebuildMounts()
    }

    func rebuildMounts() {
        if configuredDrives.count == 1, let onlyDrive = configuredDrives.first,
            let index = [6, 5, 7].firstIndex(of: onlyDrive.slot)
        {
            slot.selectItem(at: index)
        }

        let content = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: max(180, disks.count * 42)))
        let previousMounts = mountChoices.map { choice -> DriveAddress? in
            choice.indexOfSelectedItem > 0 ? listedDrives[choice.indexOfSelectedItem - 1] : nil
        }
        listedDrives = configuredDrives
        let previousNames = diskNameFields.map { $0.stringValue }
        mountChoices = []
        diskNameFields = []
        for (index, disk) in disks.enumerated() {
            let y = content.bounds.height - CGFloat((index + 1) * 42)
            let label = NSTextField(
                string: previousNames.indices.contains(index) ? previousNames[index] : disk.lastPathComponent)
            label.frame = NSRect(x: 10, y: y + 7, width: 278, height: 28)
            label.lineBreakMode = .byTruncatingMiddle
            label.toolTip = disk.lastPathComponent
            content.addSubview(label)
            diskNameFields.append(label)
            let choice = NSPopUpButton(frame: NSRect(x: 296, y: y + 7, width: 234, height: 28))
            choice.addItem(withTitle: "Not initially mounted")
            choice.addItems(withTitles: configuredDrives.map { $0.label })
            let bootSlot = [6, 5, 7][slot.indexOfSelectedItem]
            var desired =
                previousMounts.indices.contains(index)
                ? previousMounts[index] : DriveAddress(slot: bootSlot, drive: index)
            if index == 0, configuredDrives.count == 1,
                !previousMounts.contains(where: { $0 == configuredDrives[0] })
            {
                desired = configuredDrives[0]
            }
            if let desired = desired, let address = configuredDrives.firstIndex(of: desired) {
                choice.selectItem(at: address + 1)
            }
            content.addSubview(choice)
            mountChoices.append(choice)
        }
        mountList.documentView = content
    }

    @objc func chooseIcon(_ sender: Any?) {
        guard let disk = disks.first else {
            showError("Choose a disk first.")
            return
        }

        let picker = IconPicker()
        iconPicker = picker
        picker.show(diskName: disk.deletingPathExtension().lastPathComponent) { [weak self] data in
            self?.iconData = data
            self?.iconPreview.image = NSImage(data: data)
        }
    }

    @objc func createPlayer(_ sender: Any?) {
        guard !disks.isEmpty else {
            showError("Choose a disk first.")
            return
        }

        let name: String
        do {
            name = try PlayerManifest.checkedName(appName.stringValue)
        } catch {
            showError(error.localizedDescription)
            return
        }

        let mounts = mountChoices.enumerated().compactMap { index, choice -> DiskMount? in
            choice.indexOfSelectedItem == 0
                ? nil : DiskMount(diskIndex: index, address: configuredDrives[choice.indexOfSelectedItem - 1])
        }

        let diskNames = diskNameFields.map { $0.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) }
        do {
            try PlayerManifest.make(
                disks: disks.map { $0.lastPathComponent }, slot: [6, 5, 7][slot.indexOfSelectedItem],
                mounts: mounts, diskNames: diskNames, availableDrives: configuredDrives,
                initialSpeed: EmulationSpeed.allCases[speed.indexOfSelectedItem],
                startInFullScreen: fullScreen.state == .on
            ).validate()
        } catch {
            showError(error.localizedDescription)
            return
        }
        if let existing = editingPlayer {
            guard
                !NSWorkspace.shared.runningApplications.contains(where: {
                    $0.bundleURL?.standardizedFileURL == existing.standardizedFileURL
                })
            else {
                showError("Quit this player before saving changes.")
                return
            }
            do {
                try PlayerExporter.update(
                    app: existing, disks: disks, slot: [6, 5, 7][slot.indexOfSelectedItem], icon: iconData,
                    displayName: name, mounts: mounts, diskNames: diskNames,
                    availableDrives: configuredDrives,
                    initialSpeed: EmulationSpeed.allCases[speed.indexOfSelectedItem],
                    startInFullScreen: fullScreen.state == .on)
                loadPlayer(existing)
                summary.stringValue = "Saved changes to \(existing.lastPathComponent)"
            } catch {
                showError(error.localizedDescription)
            }
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = name + ".app"
        guard panel.runModal() == .OK, let output = panel.url else {
            return
        }
        do {
            let template = Bundle.main.resourceURL!.appendingPathComponent("PlayerTemplate.app")
            try PlayerExporter.export(
                disks: disks, slot: [6, 5, 7][slot.indexOfSelectedItem], template: template,
                destination: output, icon: iconData, displayName: name, mounts: mounts, diskNames: diskNames,
                availableDrives: configuredDrives,
                initialSpeed: EmulationSpeed.allCases[speed.indexOfSelectedItem],
                startInFullScreen: fullScreen.state == .on)
            NSWorkspace.shared.activateFileViewerSelecting([output])
        } catch {
            showError(error.localizedDescription)
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard filenames.count == 1 else {
            sender.reply(toOpenOrPrint: .failure)
            return
        }

        let url = URL(fileURLWithPath: filenames[0])
        if window == nil {
            pendingPlayer = url
        } else {
            loadPlayer(url)
        }
        sender.reply(toOpenOrPrint: .success)
    }

    @objc func openPlayerPanel(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["app"]
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        loadPlayer(url)
    }

    @objc func newPlayer(_ sender: Any?) {
        editingPlayer = nil
        disks = []
        diskNameFields = []
        mountChoices = []
        iconData = nil
        iconPreview.image = nil
        appName.stringValue = ""
        fullScreen.state = .off
        speed.selectItem(at: 0)
        slot.selectItem(at: 0)
        for (i, count) in driveCounts.enumerated() {
            count.selectItem(at: i == 0 ? 1 : 0)
        }
        heading.stringValue = "Create a standalone Apple II player"
        exportButton.title = "Create Player…"
        window.title = "Apple II Wrapper Builder"
        summary.stringValue = "Choose disks, or drop an existing player here to edit it."
        rebuildMounts()
    }

    func loadPlayer(_ url: URL) {
        do {
            let manifest = try PlayerExporter.read(app: url)
            let resources = url.appendingPathComponent("Contents/Resources")
            let info =
                try PropertyListSerialization.propertyList(
                    from: Data(contentsOf: url.appendingPathComponent("Contents/Info.plist")), format: nil)
                as? [String: Any]
            disks = manifest.diskFiles.map { resources.appendingPathComponent($0) }
            diskNameFields = []
            mountChoices = []
            appName.stringValue =
                info?["CFBundleDisplayName"] as? String ?? info?["CFBundleName"] as? String
                ?? url.deletingPathExtension().lastPathComponent
            for (index, count) in driveCounts.enumerated() {
                count.selectItem(
                    at: manifest.drives.filter { $0.slot == [6, 5, 7][index] }.map { $0.drive + 1 }.max() ?? 0
                )
            }
            slot.selectItem(at: [6, 5, 7].firstIndex(of: manifest.bootSlot)!)
            speed.selectItem(at: EmulationSpeed.allCases.firstIndex(of: manifest.initialSpeed ?? .oneMHz)!)
            fullScreen.state = manifest.startInFullScreen == true ? .on : .off
            rebuildMounts()
            for index in disks.indices {
                diskNameFields[index].stringValue = manifest.diskName(at: index)
                let address = manifest.mounts.first { $0.diskIndex == index }?.address
                mountChoices[index].selectItem(
                    at: address.flatMap { configuredDrives.firstIndex(of: $0) }.map { $0 + 1 } ?? 0)
            }
            iconData = try? Data(contentsOf: resources.appendingPathComponent("PlayerIcon.png"))
            iconPreview.image =
                iconData.flatMap { NSImage(data: $0) } ?? NSWorkspace.shared.icon(forFile: url.path)
            heading.stringValue = "Edit this Apple II player"
            editingPlayer = url
            exportButton.title = "Save"
            window.title = "Edit \(url.lastPathComponent)"
            summary.stringValue = "Editing \(url.lastPathComponent)"
            window.makeKeyAndOrderFront(nil)
        } catch {
            showError(error.localizedDescription)
        }
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Could not update player"
        alert.informativeText = message
        alert.runModal()
    }
}
