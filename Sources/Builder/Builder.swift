import Cocoa
@main final class Builder: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var disks: [URL] = []
    var iconData: Data?
    var iconPicker: IconPicker?
    let iconPreview = NSImageView(frame: NSRect(x: 506, y: 86, width: 84, height: 84))
    let appName = NSTextField(string: "")
    let mountList = NSScrollView(frame: NSRect(x: 28, y: 198, width: 564, height: 180))
    var listedDrives: [DriveAddress] = []
    var driveCounts: [NSPopUpButton] = []
    var configuredDrives: [DriveAddress] { zip([6,5,7], driveCounts).flatMap { slot, count in (0..<count.indexOfSelectedItem).map { DriveAddress(slot: slot, drive: $0) } } }
    var diskNameFields: [NSTextField] = []
    var mountChoices: [NSPopUpButton] = []
    let summary = NSTextField(labelWithString: "Choose disk images to package.")
    let fullScreen = NSButton(checkboxWithTitle: "Start in full screen", target: nil, action: nil)
    let speed = NSPopUpButton(frame: .zero)
    let slot = NSPopUpButton(frame: .zero)
    var delegateLifetime: Builder?
    static func main() {
        if CommandLine.arguments.contains("--export") {
            do {
                let args = CommandLine.arguments
                func value(_ flag: String) -> String { args[args.firstIndex(of: flag)! + 1] }
                try PlayerExporter.export(disks: [URL(fileURLWithPath: value("--export"))], slot: Int(value("--boot-slot"))!, template: URL(fileURLWithPath: value("--template")), destination: URL(fileURLWithPath: value("--output")), displayName: args.contains("--name") ? value("--name") : nil)
                print("Player exported."); return
            } catch { fputs("\(error.localizedDescription)\n", stderr); exit(1) }
        }
        let delegate = Builder()
        delegate.delegateLifetime = delegate
        NSApplication.shared.delegate = delegate
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.run()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem(); let app = NSMenu(title: "Apple II Wrapper Builder")
        app.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = app; menu.addItem(appItem); NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 710), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Apple II Wrapper Builder"
        let root = window.contentView!
        let title = NSTextField(labelWithString: "Create a standalone Apple II player")
        title.font = .boldSystemFont(ofSize: 20); title.frame = NSRect(x: 28, y: 650, width: 560, height: 32); root.addSubview(title)
        summary.frame = NSRect(x: 212, y: 608, width: 380, height: 32); summary.lineBreakMode = .byWordWrapping; root.addSubview(summary)
        let choose = NSButton(title: "Choose Disks…", target: self, action: #selector(chooseDisks(_:)))
        choose.frame = NSRect(x: 28, y: 608, width: 160, height: 32); choose.bezelStyle = .rounded; root.addSubview(choose)
        let label = NSTextField(labelWithString: "Start up from:"); label.frame = NSRect(x: 28, y: 511, width: 110, height: 24); root.addSubview(label)
        slot.frame = NSRect(x: 140, y: 508, width: 452, height: 28)
        slot.addItems(withTitles: ["Slot 6 — 5.25-inch floppy", "Slot 5 — 3.5-inch floppy", "Slot 7 — hard disk / SmartPort"]); root.addSubview(slot)
        let speedLabel = NSTextField(labelWithString: "Initial speed:"); speedLabel.frame = NSRect(x: 28, y: 465, width: 110, height: 24); root.addSubview(speedLabel)
        speed.frame = NSRect(x: 140, y: 462, width: 452, height: 28); speed.addItems(withTitles: EmulationSpeed.allCases.map { $0.label }); root.addSubview(speed)
        align(label, with: slot); align(speedLabel, with: speed)
        slot.target = self; slot.action = #selector(startupChanged(_:))
        let nameLabel = NSTextField(labelWithString: "App name:"); nameLabel.frame = NSRect(x: 28, y: 558, width: 110, height: 24); root.addSubview(nameLabel)
        appName.frame = NSRect(x: 140, y: 555, width: 452, height: 28); appName.placeholderString = "Name of the exported app"; root.addSubview(appName); align(nameLabel, with: appName)
        let mounted = NSTextField(labelWithString: "Disk names and initial drives"); mounted.frame = NSRect(x: 28, y: 379, width: 564, height: 24); root.addSubview(mounted)
        for (index, title) in ["5.25-inch", "3.5-inch", "SmartPort"].enumerated() {
            let x = CGFloat(28 + index * 190)
            let label = NSTextField(labelWithString: title + " drives:"); label.frame = NSRect(x: x, y: 410, width: 110, height: 24); root.addSubview(label)
            let count = NSPopUpButton(frame: NSRect(x: x+108, y: 407, width: 70, height: 28))
            count.addItems(withTitles: (0...(index == 2 ? 16 : 2)).map { String($0) })
            count.selectItem(at: index == 0 ? 1 : 0); count.target = self; count.action = #selector(drivesChanged(_:)); root.addSubview(count); driveCounts.append(count); align(label, with: count)
        }
        mountList.hasVerticalScroller = true; mountList.borderType = .bezelBorder; root.addSubview(mountList)
        let help = NSTextField(wrappingLabelWithString: "Leave extra images unmounted; swap them into a drive later through Emulation → Disks.")
        help.frame = NSRect(x: 28, y: 146, width: 450, height: 40); root.addSubview(help)
        root.addSubview(iconPreview)
        let icon = NSButton(title: "Choose Player Icon…", target: self, action: #selector(chooseIcon(_:)))
        icon.frame = NSRect(x: 28, y: 102, width: 210, height: 32); icon.bezelStyle = .rounded; root.addSubview(icon)
        fullScreen.frame = NSRect(x: 28, y: 63, width: 280, height: 24); root.addSubview(fullScreen)
        let export = NSButton(title: "Create Player…", target: self, action: #selector(createPlayer(_:)))
        export.frame = NSRect(x: 402, y: 25, width: 190, height: 34); export.bezelStyle = .rounded; root.addSubview(export)
        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    func align(_ label: NSTextField, with control: NSView) {
        let width = label.frame.width
        label.sizeToFit()
        label.frame = NSRect(x: label.frame.minX, y: control.frame.midY - label.frame.height / 2, width: width, height: label.frame.height)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }
    @objc func chooseDisks(_ sender: Any?) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["woz", "dsk", "do", "po", "2mg", "hdv", "nib"]
        guard panel.runModal() == .OK else { return }
        let previousDefault = disks.first?.deletingPathExtension().lastPathComponent
        diskNameFields = []; mountChoices = []
        disks = panel.urls; summary.stringValue = "\(disks.count) disk image\(disks.count == 1 ? "" : "s") selected"
        if appName.stringValue.isEmpty || appName.stringValue == previousDefault { appName.stringValue = disks[0].deletingPathExtension().lastPathComponent }
        rebuildMounts()
    }
    @objc func startupChanged(_ sender: Any?) {
        mountChoices = []
        for (index, count) in driveCounts.enumerated() { count.selectItem(at: index == slot.indexOfSelectedItem ? 1 : 0) }
        rebuildMounts()
    }
    @objc func drivesChanged(_ sender: Any?) { rebuildMounts() }
    func rebuildMounts() {
        if configuredDrives.count == 1, let onlyDrive = configuredDrives.first, let index = [6,5,7].firstIndex(of: onlyDrive.slot) { slot.selectItem(at: index) }
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 540, height: max(180, disks.count * 42)))
        let previousMounts = mountChoices.map { choice -> DriveAddress? in
            choice.indexOfSelectedItem > 0 ? listedDrives[choice.indexOfSelectedItem-1] : nil
        }
        listedDrives = configuredDrives
        let previousNames = diskNameFields.map { $0.stringValue }
        mountChoices = []; diskNameFields = []
        for (index, disk) in disks.enumerated() {
            let y = content.bounds.height - CGFloat((index+1)*42)
            let label = NSTextField(string: previousNames.indices.contains(index) ? previousNames[index] : disk.lastPathComponent)
            label.frame = NSRect(x: 10, y: y+7, width: 278, height: 28); label.lineBreakMode = .byTruncatingMiddle; label.toolTip = disk.lastPathComponent; content.addSubview(label); diskNameFields.append(label)
            let choice = NSPopUpButton(frame: NSRect(x: 296, y: y+7, width: 234, height: 28))
            choice.addItem(withTitle: "Not initially mounted")
            choice.addItems(withTitles: configuredDrives.map { $0.label })
            let bootSlot = [6,5,7][slot.indexOfSelectedItem]
            var desired = previousMounts.indices.contains(index) ? previousMounts[index] : DriveAddress(slot: bootSlot, drive: index)
            if index == 0, configuredDrives.count == 1, !previousMounts.contains(where: { $0 == configuredDrives[0] }) { desired = configuredDrives[0] }
            if let desired = desired, let address = configuredDrives.firstIndex(of: desired) { choice.selectItem(at: address+1) }
            content.addSubview(choice); mountChoices.append(choice)
        }
        mountList.documentView = content
    }
    @objc func chooseIcon(_ sender: Any?) {
        guard let disk = disks.first else { showError("Choose a disk first."); return }
        let picker = IconPicker(); iconPicker = picker
        picker.show(diskName: disk.deletingPathExtension().lastPathComponent) { [weak self] data in
            self?.iconData = data; self?.iconPreview.image = NSImage(data: data)
        }
    }
    @objc func createPlayer(_ sender: Any?) {
        guard !disks.isEmpty else { showError("Choose a disk first."); return }
        let name: String
        do { name = try PlayerManifest.checkedName(appName.stringValue) } catch { showError(error.localizedDescription); return }
        let mounts = mountChoices.enumerated().compactMap { index, choice -> DiskMount? in
            choice.indexOfSelectedItem == 0 ? nil : DiskMount(diskIndex: index, address: configuredDrives[choice.indexOfSelectedItem-1])
        }
        let diskNames = diskNameFields.map { $0.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) }
        do { try PlayerManifest.make(disks: disks.map { $0.lastPathComponent }, slot: [6,5,7][slot.indexOfSelectedItem], mounts: mounts, diskNames: diskNames, availableDrives: configuredDrives, initialSpeed: EmulationSpeed.allCases[speed.indexOfSelectedItem], startInFullScreen: fullScreen.state == .on).validate() } catch { showError(error.localizedDescription); return }
        let panel = NSSavePanel(); panel.nameFieldStringValue = name + ".app"
        guard panel.runModal() == .OK, let output = panel.url else { return }
        do {
            let template = Bundle.main.resourceURL!.appendingPathComponent("PlayerTemplate.app")
            try PlayerExporter.export(disks: disks, slot: [6, 5, 7][slot.indexOfSelectedItem], template: template, destination: output, icon: iconData, displayName: name, mounts: mounts, diskNames: diskNames, availableDrives: configuredDrives, initialSpeed: EmulationSpeed.allCases[speed.indexOfSelectedItem], startInFullScreen: fullScreen.state == .on)
            NSWorkspace.shared.activateFileViewerSelecting([output])
        } catch { showError(error.localizedDescription) }
    }
    func showError(_ message: String) { let alert = NSAlert(); alert.messageText = "Could not create player"; alert.informativeText = message; alert.runModal() }
}
