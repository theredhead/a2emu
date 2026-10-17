import Cocoa
import UniformTypeIdentifiers

final class PlayerDropView: NSView {
    var openFiles: (([URL]) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard
            let urls = sender.draggingPasteboard().readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty
        else {
            return false
        }
        openFiles?(urls)
        return true
    }
}

/// Decorative artwork cropped to its right side and anchored to the window's bottom edge.
final class BuilderArtworkView: NSView {
    private let artwork = Bundle.main.url(forResource: "BuilderIcon", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let artwork = artwork else { return }
        let side = max(bounds.height, bounds.width)
        artwork.draw(
            in: NSRect(x: bounds.maxX - side, y: bounds.minY, width: side, height: side),
            from: .zero, operation: .sourceOver, fraction: 1)
    }
}

@main final class Builder: NSObject, NSApplicationDelegate {
    let aboutPanel = AppAbout()

    @objc func showAbout(_ sender: Any?) {
        aboutPanel.show()
    }

    var window: NSWindow!
    var disks: [URL] = []
    private var snapshotDisksDirectory: URL?
    var startupSnapshot: URL? {
        didSet { snapshotClearButton.isHidden = startupSnapshot == nil }
    }
    let snapshotClearButton = NSButton(title: "", target: nil, action: nil)
    let snapshotLabel = NSTextField(labelWithString: "No snapshot — normal startup")
    var iconData: Data?
    var iconPicker: IconPicker?
    let iconPreview = NSImageView(frame: NSRect(x: 28, y: 76, width: 64, height: 64))
    let heading = NSTextField(labelWithString: "Create a standalone Apple IIGS player")
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
    private var hasChosenSpeed = false
    let slot = NSPopUpButton(frame: .zero)
    let memory = NSPopUpButton(frame: .zero)
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
                let disk = URL(fileURLWithPath: value("--export"))
                let bootSlot =
                    args.contains("--boot-slot")
                    ? Int(value("--boot-slot"))! : DiskImageDevice.detect(disk).slot
                try PlayerExporter.export(
                    disks: [disk], slot: bootSlot,
                    template: URL(fileURLWithPath: value("--template")),
                    destination: URL(fileURLWithPath: value("--output")),
                    displayName: args.contains("--name") ? value("--name") : nil,
                    startupSnapshot: args.contains("--snapshot")
                        ? URL(fileURLWithPath: value("--snapshot")) : nil)
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
        let app = NSMenu(title: "Apple IIGS Player Builder")
        let about = app.addItem(
            withTitle: "About Apple IIGS Player Builder", action: #selector(showAbout(_:)), keyEquivalent: "")
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
            ("New Blank Disk Image…", #selector(createBlankDisk(_:)), ""),
        ] {
            let item = fileMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
            item.target = self
        }
        fileItem.submenu = fileMenu
        menu.addItem(fileItem)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1003, height: 760),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Apple IIGS Player Builder"
        let content = PlayerDropView(frame: window.contentView!.bounds)
        content.registerForDraggedTypes([.fileURL])
        content.openFiles = { [weak self] in self?.acceptDroppedFiles($0) }
        window.contentView = content
        // The form occupies the larger part of a golden-ratio split.
        let artwork = BuilderArtworkView(frame: NSRect(x: 0, y: 0, width: 383, height: 760))
        content.addSubview(artwork)
        let root = NSView(frame: NSRect(x: 383, y: 0, width: 620, height: 760))
        content.addSubview(root)
        let title = heading
        title.font = .boldSystemFont(ofSize: 20)
        title.frame = NSRect(x: 28, y: 700, width: 560, height: 32)
        root.addSubview(title)
        summary.frame = NSRect(x: 212, y: 658, width: 380, height: 32)
        summary.lineBreakMode = .byWordWrapping
        root.addSubview(summary)
        let choose = NSButton(title: "Choose Disks…", target: self, action: #selector(chooseDisks(_:)))
        choose.frame = NSRect(x: 28, y: 658, width: 160, height: 32)
        choose.bezelStyle = .rounded
        root.addSubview(choose)
        align(summary, with: choose)
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
        speed.frame = NSRect(x: 140, y: 462, width: 128, height: 28)
        speed.addItems(withTitles: EmulationSpeed.allCases.map { $0.label })
        speed.selectItem(at: EmulationSpeed.allCases.firstIndex(of: .twoPointEightMHz)!)
        speed.target = self
        speed.action = #selector(speedChanged(_:))
        root.addSubview(speed)
        let memoryLabel = NSTextField(labelWithString: "Expansion RAM:")
        memoryLabel.frame = NSRect(x: 284, y: 465, width: 112, height: 24)
        root.addSubview(memoryLabel)
        memory.frame = NSRect(x: 398, y: 462, width: 194, height: 28)
        memory.addItems(
            withTitles: PlayerManifest.expansionMemoryChoices.map {
                $0 == 0 ? "None (built-in only)" : ($0 < 1024 ? "\($0) KB" : "\($0 / 1024) MB")
            })
        memory.selectItem(at: PlayerManifest.expansionMemoryChoices.firstIndex(of: 8192)!)
        memory.toolTip =
            "Additional RAM beyond the ROM model's built-in memory. ROM 01 starts with 256 KB; ROM 03 has about 1 MB."
        root.addSubview(memory)
        align(memoryLabel, with: memory)
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
                "Leave extra images unmounted; swap them into a drive later through the Disks menu.")
        help.frame = NSRect(x: 28, y: 146, width: 450, height: 40)
        root.addSubview(help)
        iconPreview.image = NSImage(named: NSImage.Name("PlayerIcon"))
        root.addSubview(iconPreview)
        let icon = NSButton(title: "Choose Player Icon…", target: self, action: #selector(chooseIcon(_:)))
        icon.frame = NSRect(x: 108, y: 92, width: 210, height: 32)
        icon.bezelStyle = .rounded
        root.addSubview(icon)
        fullScreen.frame = NSRect(x: 28, y: 30, width: 280, height: 24)
        root.addSubview(fullScreen)
        let export = exportButton
        export.target = self
        export.action = #selector(createPlayer(_:))
        export.frame = NSRect(x: 402, y: 25, width: 190, height: 34)
        export.bezelStyle = .rounded
        root.addSubview(export)
        let snapshotButton = NSButton(
            title: "Startup Snapshot…", target: self, action: #selector(chooseSnapshot(_:)))
        snapshotButton.bezelStyle = .rounded
        snapshotButton.frame = NSRect(x: 28, y: 610, width: 160, height: 32)
        root.addSubview(snapshotButton)
        snapshotLabel.frame = NSRect(x: 212, y: 614, width: 334, height: 24)
        snapshotLabel.lineBreakMode = .byTruncatingMiddle
        root.addSubview(snapshotLabel)
        let clearSnapshot = snapshotClearButton
        clearSnapshot.target = self
        clearSnapshot.action = #selector(clearSnapshot(_:))
        clearSnapshot.image = NSImage(
            systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Remove startup snapshot")
        clearSnapshot.imagePosition = .imageOnly
        clearSnapshot.isBordered = false
        clearSnapshot.isHidden = startupSnapshot == nil
        clearSnapshot.toolTip = "Remove startup snapshot and use normal startup"
        clearSnapshot.bezelStyle = .rounded
        clearSnapshot.frame = NSRect(x: 558, y: 614, width: 28, height: 24)
        root.addSubview(clearSnapshot)
        snapshotButton.toolTip = "Optional: restore the captured speed and disk state on every launch."
        for y: CGFloat in [598, 66] {
            let separator = NSBox(frame: NSRect(x: 28, y: y, width: 564, height: 1))
            separator.boxType = .separator
            root.addSubview(separator)
        }
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

    @objc func chooseSnapshot(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowedContentTypes = [UTType(exportedAs: "nl.theredhead.a2emu.snapshot")]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try selectSnapshot(url) } catch { showError(error.localizedDescription) }
    }

    /// Validates the entire drop before changing selection; snapshots supply their own disks.
    func acceptDroppedFiles(_ urls: [URL]) {
        do {
            if urls.count == 1, let url = urls.first {
                if url.pathExtension.lowercased() == "app" {
                    loadPlayer(url)
                    return
                }
                if url.pathExtension.lowercased() == PlayerSnapshot.fileExtension {
                    try selectSnapshot(url)
                    return
                }
            }
            let extensions = ["woz", "dsk", "do", "po", "2mg", "2img", "hdv", "nib"]
            guard !urls.isEmpty,
                urls.allSatisfy({
                    extensions.contains($0.pathExtension.lowercased())
                        && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                })
            else {
                throw PlayerManifest.failure("Drop disk images, one snapshot, or one existing player.")
            }
            selectDisks(urls)
        } catch { showError(error.localizedDescription) }
    }

    /// Expands private working copies before applying the snapshot's name, RAM and mounted drives.
    /// Failed imports leave the current form and media intact.
    func selectSnapshot(_ url: URL) throws {
        let snapshot = try PlayerSnapshot.read(at: url)
        let capturedMemory = try snapshot.capturedExpansionMemoryKB(at: url)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            for name in snapshot.diskFiles {
                try snapshot.extract(name, from: url, to: directory.appendingPathComponent(name))
            }
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
        selectDisks(snapshot.diskFiles.map { directory.appendingPathComponent($0) })
        snapshotDisksDirectory = directory
        appName.stringValue = snapshot.gameName
        if let index = PlayerManifest.expansionMemoryChoices.firstIndex(of: capturedMemory) {
            memory.selectItem(at: index)
        }
        for (index, count) in driveCounts.enumerated() {
            let slot = [6, 5, 7][index]
            let required =
                snapshot.mounts.filter { $0.address.slot == slot }.map { $0.address.drive + 1 }.max() ?? 0
            count.selectItem(at: required)
        }
        if let boot = snapshot.mounts.first(where: { $0.diskIndex == 0 }) ?? snapshot.mounts.first,
            let index = [6, 5, 7].firstIndex(of: boot.address.slot)
        {
            slot.selectItem(at: index)
        }
        rebuildMounts()
        for index in disks.indices {
            let address = snapshot.mounts.first { $0.diskIndex == index }?.address
            mountChoices[index].selectItem(
                at: address.flatMap { configuredDrives.firstIndex(of: $0) }.map { $0 + 1 } ?? 0)
        }
        memory.isEnabled = false
        startupSnapshot = url
        speed.isEnabled = false
        speed.toolTip = "The startup snapshot restores its captured speed."
        snapshotLabel.stringValue = snapshot.title
        snapshotLabel.toolTip = url.path
    }

    private func removeSnapshotWorkingDisks() {
        if let directory = snapshotDisksDirectory { try? FileManager.default.removeItem(at: directory) }
        snapshotDisksDirectory = nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeSnapshotWorkingDisks()
    }

    @objc func clearSnapshot(_ sender: Any?) {
        startupSnapshot = nil
        speed.isEnabled = true
        memory.isEnabled = true
        speed.toolTip = nil
        snapshotLabel.stringValue = "No snapshot — normal startup"
        snapshotLabel.toolTip = nil
    }

    @objc func createBlankDisk(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "New Blank Disk Image"
        alert.informativeText =
            "Create an empty writable disk. Initialize it inside the emulated computer before saving files to it. Blank disks do not contain a bootable system."
        alert.addButton(withTitle: "Continue…")
        alert.addButton(withTitle: "Cancel")
        let options = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 70))
        let format = NSPopUpButton(frame: NSRect(x: 0, y: 38, width: 340, height: 28))
        format.addItems(withTitles: BlankDiskImage.allCases.map { $0.label })
        format.selectItem(at: 1)
        options.addSubview(format)
        let add = NSButton(checkboxWithTitle: "Add to this player's disks", target: nil, action: nil)
        add.frame = NSRect(x: 0, y: 0, width: 340, height: 28)
        add.isEnabled = startupSnapshot == nil
        add.state = startupSnapshot == nil ? .on : .off
        add.toolTip =
            startupSnapshot == nil ? nil : "Clear the startup snapshot before changing its disk set."
        options.addSubview(add)
        alert.accessoryView = options
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let image = BlankDiskImage.allCases[format.indexOfSelectedItem]
        let panel = NSSavePanel()
        panel.title = "Save Blank Disk Image"
        panel.nameFieldStringValue = "Untitled." + image.fileExtension
        panel.allowedContentTypes = [UTType(filenameExtension: image.fileExtension) ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard !disks.contains(where: { $0.standardizedFileURL == url.standardizedFileURL }) else {
                throw PlayerManifest.failure(
                    "Choose a new file instead of replacing a disk selected in this player.")
            }
            try image.write(to: url)
            if add.state == .on {
                if disks.isEmpty {
                    selectDisks([url])
                } else {
                    disks.append(url)
                    rebuildMounts()
                    mountChoices.last?.selectItem(at: 0)
                    summary.stringValue = "\(disks.count) disk images selected"
                }
            }
        } catch { showError(error.localizedDescription) }
    }

    @objc func chooseDisks(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = ["woz", "dsk", "do", "po", "2mg", "2img", "hdv", "nib"].compactMap {
            UTType(filenameExtension: $0)
        }
        guard panel.runModal() == .OK else {
            return
        }

        selectDisks(panel.urls)
    }

    /// Selects the initial boot drive from the first image; drive controls remain editable.
    func selectDisks(_ urls: [URL]) {
        guard let bootImage = urls.first else { return }
        clearSnapshot(nil)
        removeSnapshotWorkingDisks()
        let previousDefault = disks.first?.deletingPathExtension().lastPathComponent
        diskNameFields = []
        mountChoices = []
        disks = urls
        summary.stringValue = "\(disks.count) disk image\(disks.count == 1 ? "" : "s") selected"
        if appName.stringValue.isEmpty || appName.stringValue == previousDefault {
            appName.stringValue = disks[0].deletingPathExtension().lastPathComponent
        }
        if let index = [6, 5, 7].firstIndex(of: DiskImageDevice.detect(bootImage).slot) {
            slot.selectItem(at: index)
        }
        startupChanged(nil)
    }

    @objc func startupChanged(_ sender: Any?) {
        mountChoices = []
        for (index, count) in driveCounts.enumerated() {
            count.selectItem(at: index == slot.indexOfSelectedItem ? 1 : 0)
        }
        rebuildMounts()
    }

    @objc func speedChanged(_ sender: Any?) {
        hasChosenSpeed = true
    }

    /// Only untouched defaults follow the boot device; explicit and saved speeds take precedence.
    private func updateAutomaticSpeed() {
        guard !disks.isEmpty, !hasChosenSpeed, startupSnapshot == nil, slot.indexOfSelectedItem >= 0 else {
            return
        }
        let bootSlot = [6, 5, 7][slot.indexOfSelectedItem]
        let defaultSpeed: EmulationSpeed = bootSlot == 6 ? .oneMHz : .twoPointEightMHz
        if let index = EmulationSpeed.allCases.firstIndex(of: defaultSpeed) {
            speed.selectItem(at: index)
        }
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

        updateAutomaticSpeed()
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
        let name = appName.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchName = name.isEmpty ? disk.deletingPathExtension().lastPathComponent : name
        picker.show(searchName: searchName) { [weak self] data in
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
                    startInFullScreen: fullScreen.state == .on, startupSnapshot: startupSnapshot,
                    expansionMemoryKB: PlayerManifest.expansionMemoryChoices[memory.indexOfSelectedItem])
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
                startInFullScreen: fullScreen.state == .on, startupSnapshot: startupSnapshot,
                expansionMemoryKB: PlayerManifest.expansionMemoryChoices[memory.indexOfSelectedItem])
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
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        loadPlayer(url)
    }

    @objc func newPlayer(_ sender: Any?) {
        editingPlayer = nil
        removeSnapshotWorkingDisks()
        clearSnapshot(nil)
        disks = []
        diskNameFields = []
        mountChoices = []
        iconData = nil
        iconPreview.image = NSImage(named: NSImage.Name("PlayerIcon"))
        appName.stringValue = ""
        fullScreen.state = .off
        hasChosenSpeed = false
        memory.selectItem(at: PlayerManifest.expansionMemoryChoices.firstIndex(of: 8192)!)
        speed.selectItem(at: EmulationSpeed.allCases.firstIndex(of: .twoPointEightMHz)!)
        slot.selectItem(at: 0)
        for (i, count) in driveCounts.enumerated() {
            count.selectItem(at: i == 0 ? 1 : 0)
        }
        heading.stringValue = "Create a standalone Apple IIGS player"
        exportButton.title = "Create Player…"
        window.title = "Apple IIGS Player Builder"
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
            removeSnapshotWorkingDisks()
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
            hasChosenSpeed = true
            memory.selectItem(
                at: PlayerManifest.expansionMemoryChoices.firstIndex(of: manifest.expansionMemoryKB ?? 8192)!)
            fullScreen.state = manifest.startInFullScreen == true ? .on : .off
            startupSnapshot =
                manifest.startupSnapshot == true
                ? resources.appendingPathComponent("Startup.a2snapshot") : nil
            memory.isEnabled = startupSnapshot == nil
            speed.isEnabled = startupSnapshot == nil
            snapshotLabel.stringValue =
                startupSnapshot == nil ? "No snapshot — normal startup" : "Bundled startup snapshot"
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
            heading.stringValue = "Edit this Apple IIGS player"
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
