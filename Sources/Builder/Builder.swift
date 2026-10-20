import Cocoa
import UniformTypeIdentifiers

private let builderIntl = BuilderIntl()
private let commonIntl = CommonIntl()

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
    let snapshotLabel = NSTextField(labelWithString: builderIntl.normalStartup)
    var iconData: Data?
    var iconPicker: IconPicker?
    let iconPreview = NSImageView(frame: NSRect(x: 28, y: 76, width: 64, height: 64))
    let heading = NSTextField(labelWithString: builderIntl.createPlayerHeading)
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
    let summary = NSTextField(labelWithString: builderIntl.chooseDisksHint)
    let fullScreen = NSButton(checkboxWithTitle: builderIntl.startInFullScreen, target: nil, action: nil)
    let speed = NSPopUpButton(frame: .zero)
    private var hasChosenSpeed = false
    let slot = NSPopUpButton(frame: .zero)
    let memory = NSPopUpButton(frame: .zero)
    var editingPlayer: URL?
    var pendingPlayer: URL?
    let exportButton = NSButton(title: builderIntl.createPlayer, target: nil, action: nil)
    private var modifierMonitor: Any?
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
        let app = NSMenu(title: builderIntl.appleIigsPlayerBuilder)
        let about = app.addItem(
            withTitle: builderIntl.aboutAppleIigsPlayerBuilder, action: #selector(showAbout(_:)),
            keyEquivalent: "")
        about.target = self
        app.addItem(NSMenuItem.separator())
        app.addItem(
            withTitle: commonIntl.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = app
        menu.addItem(appItem)
        NSApp.mainMenu = menu
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: commonIntl.file)
        for (title, action, key) in [
            (builderIntl.newPlayer, #selector(newPlayer(_:)), "n"),
            (builderIntl.openPlayer, #selector(openPlayerPanel(_:)), "o"),
            (builderIntl.newBlankDiskImage, #selector(createBlankDisk(_:)), ""),
        ] {
            let item = fileMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
            item.target = self
        }
        fileItem.submenu = fileMenu
        menu.addItem(fileItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: builderIntl.editMenu)
        let pasteItem = editMenu.addItem(
            withTitle: builderIntl.paste, action: #selector(paste(_:)), keyEquivalent: "v")
        pasteItem.target = self
        editItem.submenu = editMenu
        menu.addItem(editItem)
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1003, height: 760),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = builderIntl.appleIigsPlayerBuilder
        let content = PlayerDropView(frame: window.contentView!.bounds)
        content.registerForDraggedTypes([.fileURL, .png, .tiff])
        content.openFiles = { [weak self] in self?.acceptDroppedFiles($0) }
        content.openImage = { [weak self] in self?.selectIconImage($0) }
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
        let choose = NSButton(
            title: builderIntl.chooseDisks, target: self, action: #selector(chooseDisks(_:)))
        choose.frame = NSRect(x: 28, y: 658, width: 160, height: 32)
        choose.bezelStyle = .rounded
        root.addSubview(choose)
        align(summary, with: choose)
        let label = NSTextField(labelWithString: builderIntl.startUpFrom)
        label.frame = NSRect(x: 28, y: 511, width: 110, height: 24)
        root.addSubview(label)
        slot.frame = NSRect(x: 140, y: 508, width: 452, height: 28)
        slot.addItems(withTitles: [
            builderIntl.bootFloppy525, builderIntl.bootFloppy35, builderIntl.bootSmartPort,
        ])
        root.addSubview(slot)
        let speedLabel = NSTextField(labelWithString: builderIntl.initialSpeed)
        speedLabel.frame = NSRect(x: 28, y: 465, width: 110, height: 24)
        root.addSubview(speedLabel)
        speed.frame = NSRect(x: 140, y: 462, width: 128, height: 28)
        speed.addItems(withTitles: EmulationSpeed.allCases.map { $0.label })
        speed.selectItem(at: EmulationSpeed.allCases.firstIndex(of: .twoPointEightMHz)!)
        speed.target = self
        speed.action = #selector(speedChanged(_:))
        root.addSubview(speed)
        let memoryLabel = NSTextField(labelWithString: builderIntl.expansionRam)
        memoryLabel.frame = NSRect(x: 284, y: 465, width: 112, height: 24)
        root.addSubview(memoryLabel)
        memory.frame = NSRect(x: 398, y: 462, width: 194, height: 28)
        memory.addItems(
            withTitles: PlayerManifest.expansionMemoryChoices.map {
                $0 == 0
                    ? builderIntl.noneBuiltInOnly
                    : ($0 < 1024
                        ? builderIntl.kilobytes(kilobytes: $0) : builderIntl.megabytes(megabytes: $0 / 1024))
            })
        memory.selectItem(at: PlayerManifest.expansionMemoryChoices.firstIndex(of: 8192)!)
        memory.toolTip =
            builderIntl.expansionRAMHint
        root.addSubview(memory)
        align(memoryLabel, with: memory)
        align(label, with: slot)
        align(speedLabel, with: speed)
        slot.target = self
        slot.action = #selector(startupChanged(_:))
        let nameLabel = NSTextField(labelWithString: builderIntl.appName)
        nameLabel.frame = NSRect(x: 28, y: 558, width: 110, height: 24)
        root.addSubview(nameLabel)
        appName.frame = NSRect(x: 140, y: 555, width: 452, height: 28)
        appName.placeholderString = builderIntl.appNamePlaceholder
        root.addSubview(appName)
        align(nameLabel, with: appName)
        let mounted = NSTextField(labelWithString: builderIntl.diskNamesAndInitialDrives)
        mounted.frame = NSRect(x: 28, y: 379, width: 564, height: 24)
        root.addSubview(mounted)
        for (index, title) in [commonIntl.floppy525Type, commonIntl.floppy35Type, "SmartPort"].enumerated() {
            let x = CGFloat(28 + index * 190)
            let label = NSTextField(labelWithString: builderIntl.drives(title: title))
            let labelWidth = max(102, ceil(label.intrinsicContentSize.width) + 4)
            label.frame = NSRect(x: x, y: 410, width: labelWidth, height: 24)
            root.addSubview(label)
            let count = NSPopUpButton(
                frame: NSRect(x: x + labelWidth + 6, y: 407, width: 172 - labelWidth, height: 28))
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
                builderIntl.unmountedDisksHint)
        help.frame = NSRect(x: 28, y: 146, width: 450, height: 40)
        root.addSubview(help)
        iconPreview.image = NSImage(named: NSImage.Name("PlayerIcon"))
        root.addSubview(iconPreview)
        let icon = NSButton(
            title: builderIntl.choosePlayerIcon, target: self, action: #selector(chooseIcon(_:)))
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
            title: builderIntl.startupSnapshot, target: self, action: #selector(chooseSnapshot(_:)))
        snapshotButton.bezelStyle = .rounded
        snapshotButton.frame = NSRect(
            x: 28, y: 610, width: max(160, ceil(snapshotButton.intrinsicContentSize.width)), height: 32)
        root.addSubview(snapshotButton)
        snapshotLabel.frame = NSRect(x: 212, y: 614, width: 334, height: 24)
        snapshotLabel.lineBreakMode = .byTruncatingMiddle
        root.addSubview(snapshotLabel)
        align(snapshotLabel, with: snapshotButton)
        let clearSnapshot = snapshotClearButton
        clearSnapshot.target = self
        clearSnapshot.action = #selector(clearSnapshot(_:))
        clearSnapshot.image = NSImage(
            systemSymbolName: "xmark.circle.fill", accessibilityDescription: builderIntl.removeStartupSnapshot
        )
        clearSnapshot.imagePosition = .imageOnly
        clearSnapshot.isBordered = false
        clearSnapshot.isHidden = startupSnapshot == nil
        clearSnapshot.toolTip = builderIntl.removeSnapshotHint
        clearSnapshot.bezelStyle = .rounded
        clearSnapshot.frame = NSRect(x: 558, y: 614, width: 28, height: 24)
        root.addSubview(clearSnapshot)
        snapshotButton.toolTip = builderIntl.startupSnapshotHint
        for y: CGFloat in [598, 66] {
            let separator = NSBox(frame: NSRect(x: 28, y: y, width: 564, height: 1))
            separator.boxType = .separator
            root.addSubview(separator)
        }
        modifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.refreshExportButton(optionHeld: event.modifierFlags.contains(.option))
            return event
        }
        refreshExportButton(optionHeld: NSEvent.modifierFlags.contains(.option))
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

    /// Applies players and snapshots before additional disks, then uses only the first icon image.
    func acceptDroppedFiles(_ urls: [URL]) {
        var players: [URL] = []
        var snapshots: [URL] = []
        var otherFiles: [URL] = []
        var firstImage: URL?
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "app" {
                players.append(url)
            } else if ext == PlayerSnapshot.fileExtension {
                snapshots.append(url)
            } else if let type = UTType(filenameExtension: ext), type.conforms(to: .image) {
                if firstImage == nil { firstImage = url }
            } else {
                otherFiles.append(url)
            }
        }
        var ordered = players + snapshots + otherFiles
        if let image = firstImage { ordered.append(image) }
        processDroppedFiles(ordered, unhandled: [])
    }

    /// Processes a mixed drop in order, waiting for each crop before moving to the next file.
    private func processDroppedFiles(_ urls: [URL], unhandled: [URL]) {
        var failures = unhandled
        for (index, url) in urls.enumerated() {
            do {
                let ext = url.pathExtension.lowercased()
                if ext == "app" {
                    if !loadPlayer(url, reportError: false) { failures.append(url) }
                } else if ext == PlayerSnapshot.fileExtension {
                    try selectSnapshot(url)
                } else if let type = UTType(filenameExtension: ext), type.conforms(to: .image),
                    let image = NSImage(contentsOf: url)
                {
                    let remaining = Array(urls.dropFirst(index + 1))
                    let previousFailures = failures
                    selectIconImage(image) { [weak self] accepted in
                        self?.processDroppedFiles(
                            remaining, unhandled: accepted ? previousFailures : previousFailures + [url])
                    }
                    return
                } else {
                    let extensions = ["woz", "dsk", "do", "po", "2mg", "2img", "hdv", "nib"]
                    guard extensions.contains(ext),
                        (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true
                    else {
                        failures.append(url)
                        continue
                    }
                    appendDroppedDisks([url])
                }
            } catch { failures.append(url) }
        }
        if !failures.isEmpty {
            showError(builderIntl.unhandledFiles(files: failures.map { $0.path }.joined(separator: "\n")))
        }
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
        speed.toolTip = builderIntl.snapshotSpeedHint
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
        snapshotLabel.stringValue = builderIntl.normalStartup
        snapshotLabel.toolTip = nil
    }

    private var blankDiskFormatMenu: NSPopUpButton?

    @objc func blankDiskCapacityChanged(_ sender: NSPopUpButton) {
        guard let formats = blankDiskFormatMenu else { return }
        let image = BlankDiskImage.allCases[sender.indexOfSelectedItem]
        for format in BlankDiskFormat.allCases {
            formats.item(at: format.rawValue)?.isEnabled = image.supports(format)
        }
        if !image.supports(BlankDiskFormat.allCases[formats.indexOfSelectedItem]) {
            formats.selectItem(at: BlankDiskFormat.proDOS.rawValue)
        }
    }

    @objc func createBlankDisk(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = builderIntl.blankDiskTitle
        alert.informativeText =
            builderIntl.blankDiskExplanation
        alert.addButton(withTitle: commonIntl.continueAction)
        alert.addButton(withTitle: commonIntl.cancel)
        let options = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 112))
        let capacity = NSPopUpButton(frame: NSRect(x: 104, y: 82, width: 296, height: 28))
        capacity.addItems(withTitles: BlankDiskImage.allCases.map { $0.label })
        capacity.selectItem(at: 1)
        capacity.target = self
        capacity.action = #selector(blankDiskCapacityChanged(_:))
        options.addSubview(capacity)
        let capacityLabel = NSTextField(labelWithString: builderIntl.diskCapacity)
        capacityLabel.frame = NSRect(x: 0, y: 82, width: 100, height: 24)
        align(capacityLabel, with: capacity)
        options.addSubview(capacityLabel)
        let format = NSPopUpButton(frame: NSRect(x: 104, y: 44, width: 296, height: 28))
        format.addItems(withTitles: BlankDiskFormat.allCases.map { $0.label })
        format.menu?.autoenablesItems = false
        blankDiskFormatMenu = format
        defer { blankDiskFormatMenu = nil }
        blankDiskCapacityChanged(capacity)
        options.addSubview(format)
        let formatLabel = NSTextField(labelWithString: builderIntl.diskFormat)
        formatLabel.frame = NSRect(x: 0, y: 44, width: 100, height: 24)
        align(formatLabel, with: format)
        options.addSubview(formatLabel)
        let add = NSButton(checkboxWithTitle: builderIntl.addToPlayerDisks, target: nil, action: nil)
        add.frame = NSRect(x: 0, y: 0, width: 340, height: 28)
        add.isEnabled = startupSnapshot == nil
        add.state = startupSnapshot == nil ? .on : .off
        add.toolTip =
            startupSnapshot == nil ? nil : builderIntl.snapshotDiskSetHint
        options.addSubview(add)
        alert.accessoryView = options
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let image = BlankDiskImage.allCases[capacity.indexOfSelectedItem]
        let filesystem = BlankDiskFormat.allCases[format.indexOfSelectedItem]
        let fileExtension = image.fileExtension(for: filesystem)
        let panel = NSSavePanel()
        panel.title = builderIntl.saveBlankDiskImage
        panel.nameFieldStringValue = builderIntl.untitledDisk(fileExtension: fileExtension)
        panel.allowedContentTypes = [UTType(filenameExtension: fileExtension) ?? .data]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard !disks.contains(where: { $0.standardizedFileURL == url.standardizedFileURL }) else {
                throw PlayerManifest.failure(
                    builderIntl.selectedDiskOverwriteError)
            }
            try image.write(to: url, format: filesystem)
            if add.state == .on {
                if disks.isEmpty {
                    selectDisks([url])
                } else {
                    disks.append(url)
                    rebuildMounts()
                    mountChoices.last?.selectItem(at: 0)
                    summary.stringValue = builderIntl.diskImagesSelected(count: disks.count)
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

    /// Adds dropped media without changing existing disk names, mounts or machine settings.
    func appendDroppedDisks(_ urls: [URL]) {
        var additions: [URL] = []
        var knownURLs = Set(disks.map { $0.standardizedFileURL })
        for url in urls {
            if knownURLs.insert(url.standardizedFileURL).inserted {
                additions.append(url)
            }
        }
        guard !additions.isEmpty else { return }
        if disks.isEmpty {
            selectDisks(additions)
            return
        }

        let previousMounts = mountChoices.map { $0.indexOfSelectedItem }
        let previousSlot = slot.indexOfSelectedItem
        let previousSpeed = speed.indexOfSelectedItem
        // The snapshot describes an exact disk set; retain its working copies as selected media.
        clearSnapshot(nil)
        disks.append(contentsOf: additions)
        rebuildMounts()
        slot.selectItem(at: previousSlot)
        speed.selectItem(at: previousSpeed)
        for (index, choice) in mountChoices.enumerated() {
            choice.selectItem(at: previousMounts.indices.contains(index) ? previousMounts[index] : 0)
        }
        summary.stringValue = builderIntl.diskImagesSelected(count: disks.count)
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
        summary.stringValue = builderIntl.diskImagesSelected(count: disks.count)
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
            choice.addItem(withTitle: builderIntl.notInitiallyMounted)
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
            align(label, with: choice)
            mountChoices.append(choice)
        }
        mountList.documentView = content
    }

    @objc func paste(_ sender: Any?) {
        if let image = NSImage(pasteboard: .general) {
            selectIconImage(image)
        } else if let text = window.firstResponder as? NSText {
            text.paste(sender)
        }
    }

    func selectIconImage(_ image: NSImage, completion: ((Bool) -> Void)? = nil) {
        guard image.size.width > 0, image.size.height > 0 else {
            completion?(false)
            return
        }
        if image.size.width == image.size.height {
            let crop = SquareCropView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
            crop.image = image
            if let data = crop.png() {
                iconData = data
                iconPreview.image = NSImage(data: data)
                completion?(true)
            } else {
                completion?(false)
            }
            return
        }
        let picker = IconPicker()
        iconPicker = picker
        picker.cropClosed = completion
        picker.showCrop(image: image) { [weak self] data in
            self?.iconData = data
            self?.iconPreview.image = NSImage(data: data)
        }
    }

    @objc func chooseIcon(_ sender: Any?) {
        guard let disk = disks.first else {
            showError(builderIntl.chooseADiskFirst)
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

    private func refreshExportButton(optionHeld: Bool) {
        exportButton.title =
            optionHeld
            ? builderIntl.runNow
            : (editingPlayer == nil ? builderIntl.createPlayer : commonIntl.save)
        exportButton.toolTip = builderIntl.runNowHint
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshExportButton(optionHeld: NSEvent.modifierFlags.contains(.option))
    }

    @objc func createPlayer(_ sender: Any?) {
        let runNow = NSEvent.modifierFlags.contains(.option)
        guard !disks.isEmpty else {
            showError(builderIntl.chooseADiskFirst)
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
        if runNow {
            runTemporaryPlayer(name: name, mounts: mounts, diskNames: diskNames)
            return
        }
        if let existing = editingPlayer {
            guard
                !NSWorkspace.shared.runningApplications.contains(where: {
                    $0.bundleURL?.standardizedFileURL == existing.standardizedFileURL
                })
            else {
                showError(builderIntl.quitPlayerBeforeSavingError)
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
                summary.stringValue = builderIntl.savedChangesTo(filename: existing.lastPathComponent)
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

    /// Runs an isolated export; the player also cleans up if the builder quits first.
    private func runTemporaryPlayer(name: String, mounts: [DiskMount], diskNames: [String]) {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("a2-preview-" + UUID().uuidString)
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let output = directory.appendingPathComponent(name + ".app")
            try PlayerExporter.export(
                disks: disks, slot: [6, 5, 7][slot.indexOfSelectedItem],
                template: Bundle.main.resourceURL!.appendingPathComponent("PlayerTemplate.app"),
                destination: output, icon: iconData, displayName: name, mounts: mounts, diskNames: diskNames,
                availableDrives: configuredDrives,
                initialSpeed: EmulationSpeed.allCases[speed.indexOfSelectedItem],
                startInFullScreen: fullScreen.state == .on,
                bundleIdentifier: "nl.theredhead.a2emu-player.preview." + UUID().uuidString,
                startupSnapshot: startupSnapshot,
                expansionMemoryKB: PlayerManifest.expansionMemoryChoices[memory.indexOfSelectedItem])
            let process = Process()
            process.executableURL = Bundle(url: output)!.executableURL!
            process.arguments = ["--temporary-player"]
            process.terminationHandler = { _ in try? FileManager.default.removeItem(at: directory) }
            try process.run()
        } catch {
            try? manager.removeItem(at: directory)
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
        heading.stringValue = builderIntl.createPlayerHeading
        refreshExportButton(optionHeld: NSEvent.modifierFlags.contains(.option))
        window.title = builderIntl.appleIigsPlayerBuilder
        summary.stringValue = builderIntl.emptyPlayerHint
        rebuildMounts()
    }

    @discardableResult
    func loadPlayer(_ url: URL, reportError: Bool = true) -> Bool {
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
                startupSnapshot == nil ? builderIntl.normalStartup : builderIntl.bundledStartupSnapshot
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
            heading.stringValue = builderIntl.editThisAppleIigsPlayer
            editingPlayer = url
            refreshExportButton(optionHeld: NSEvent.modifierFlags.contains(.option))
            window.title = builderIntl.edit(filename: url.lastPathComponent)
            summary.stringValue = builderIntl.editing(filename: url.lastPathComponent)
            window.makeKeyAndOrderFront(nil)
            return true
        } catch {
            if reportError { showError(error.localizedDescription) }
            return false
        }
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = builderIntl.couldNotUpdatePlayer
        alert.informativeText = message
        alert.runModal()
    }
}
