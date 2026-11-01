import Cocoa

private let builderIntl = BuilderIntl()
private let commonIntl = CommonIntl()

@objc protocol BuilderFormActions: NSObjectProtocol {
    func chooseDisks(_ sender: Any?)

    func speedChanged(_ sender: Any?)

    func startupChanged(_ sender: Any?)

    func drivesChanged(_ sender: Any?)

    func chooseIcon(_ sender: Any?)

    func createPlayer(_ sender: Any?)

    func chooseSnapshot(_ sender: Any?)

    func clearSnapshot(_ sender: Any?)

    func mountChanged(_ sender: Any?)
}

/// Owns builder controls, their layout and editable disk rows; it delegates user intent without performing I/O.
final class BuilderForm {
    var window: NSWindow!
    let snapshotClearButton = NSButton(title: "", target: nil, action: nil)
    let snapshotLabel = NSTextField(labelWithString: builderIntl.normalStartup)
    let iconPreview = NSImageView(frame: NSRect(x: 28, y: 76, width: 64, height: 64))
    let heading = NSTextField(labelWithString: builderIntl.createPlayerHeading)
    let appName = NSTextField(string: "")
    let mountList = NSScrollView(frame: NSRect(x: 28, y: 294, width: 564, height: 180))
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
    let slot = NSPopUpButton(frame: .zero)
    let memory = NSPopUpButton(frame: .zero)
    let bootLight = NSImageView(frame: NSRect(x: 376, y: 35, width: 14, height: 14))
    let exportButton = NSButton(title: builderIntl.createPlayer, target: nil, action: nil)

    func makeWindow(
        target: BuilderFormActions, openFiles: @escaping ([URL]) -> Void,
        openImage: @escaping (NSImage) -> Void
    ) {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1003, height: 760),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = builderIntl.appleIigsPlayerBuilder
        let content = PlayerDropView(frame: window.contentView!.bounds)
        content.registerForDraggedTypes([.fileURL, .png, .tiff])
        content.openFiles = openFiles
        content.openImage = openImage
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
        summary.frame = NSRect(x: 212, y: 250, width: 380, height: 32)
        summary.lineBreakMode = .byWordWrapping
        root.addSubview(summary)
        let choose = NSButton(
            title: builderIntl.chooseDisks, target: target,
            action: #selector(BuilderFormActions.chooseDisks(_:)))
        choose.frame = NSRect(x: 28, y: 250, width: 160, height: 32)
        choose.bezelStyle = .rounded
        root.addSubview(choose)
        ControlLayout.align(summary, with: choose)
        let label = NSTextField(labelWithString: builderIntl.startUpFrom)
        label.frame = NSRect(x: 28, y: 607, width: 110, height: 24)
        root.addSubview(label)
        slot.frame = NSRect(x: 140, y: 604, width: 452, height: 28)
        slot.addItems(withTitles: [
            builderIntl.bootFloppy525, builderIntl.bootFloppy35, builderIntl.bootSmartPort,
        ])
        root.addSubview(slot)
        let speedLabel = NSTextField(labelWithString: builderIntl.initialSpeed)
        speedLabel.frame = NSRect(x: 28, y: 561, width: 110, height: 24)
        root.addSubview(speedLabel)
        speed.frame = NSRect(x: 140, y: 558, width: 128, height: 28)
        speed.addItems(withTitles: EmulationSpeed.allCases.map { $0.label })
        speed.selectItem(at: EmulationSpeed.allCases.firstIndex(of: .twoPointEightMHz)!)
        speed.target = target
        speed.action = #selector(BuilderFormActions.speedChanged(_:))
        root.addSubview(speed)
        let memoryLabel = NSTextField(labelWithString: builderIntl.expansionRam)
        memoryLabel.frame = NSRect(x: 284, y: 561, width: 112, height: 24)
        root.addSubview(memoryLabel)
        memory.frame = NSRect(x: 398, y: 558, width: 194, height: 28)
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
        ControlLayout.align(memoryLabel, with: memory)
        ControlLayout.align(label, with: slot)
        ControlLayout.align(speedLabel, with: speed)
        slot.target = target
        slot.action = #selector(BuilderFormActions.startupChanged(_:))
        let nameLabel = NSTextField(labelWithString: builderIntl.appName)
        nameLabel.frame = NSRect(x: 28, y: 654, width: 110, height: 24)
        root.addSubview(nameLabel)
        appName.frame = NSRect(x: 140, y: 651, width: 452, height: 28)
        appName.placeholderString = builderIntl.appNamePlaceholder
        root.addSubview(appName)
        ControlLayout.align(nameLabel, with: appName)
        let mounted = NSTextField(labelWithString: builderIntl.diskNamesAndInitialDrives)
        mounted.frame = NSRect(x: 28, y: 475, width: 564, height: 24)
        root.addSubview(mounted)
        for (index, title) in [commonIntl.floppy525Type, commonIntl.floppy35Type, "SmartPort"].enumerated() {
            let x = CGFloat(28 + index * 190)
            let label = NSTextField(labelWithString: builderIntl.drives(title: title))
            let labelWidth = max(102, ceil(label.intrinsicContentSize.width) + 4)
            label.frame = NSRect(x: x, y: 506, width: labelWidth, height: 24)
            root.addSubview(label)
            let count = NSPopUpButton(
                frame: NSRect(x: x + labelWidth + 6, y: 503, width: 172 - labelWidth, height: 28))
            count.addItems(withTitles: (0...(index == 2 ? 16 : 2)).map { String($0) })
            count.selectItem(at: index == 0 ? 1 : 0)
            count.target = target
            count.action = #selector(BuilderFormActions.drivesChanged(_:))
            root.addSubview(count)
            driveCounts.append(count)
            ControlLayout.align(label, with: count)
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
            title: builderIntl.choosePlayerIcon, target: target,
            action: #selector(BuilderFormActions.chooseIcon(_:)))
        icon.frame = NSRect(x: 108, y: 92, width: 210, height: 32)
        icon.bezelStyle = .rounded
        root.addSubview(icon)
        fullScreen.frame = NSRect(x: 28, y: 30, width: 280, height: 24)
        root.addSubview(fullScreen)
        let export = exportButton
        export.target = target
        export.action = #selector(BuilderFormActions.createPlayer(_:))
        export.frame = NSRect(x: 402, y: 25, width: 190, height: 34)
        export.bezelStyle = .rounded
        root.addSubview(export)
        bootLight.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
        root.addSubview(bootLight)
        let snapshotButton = NSButton(
            title: builderIntl.startupSnapshot, target: target,
            action: #selector(BuilderFormActions.chooseSnapshot(_:)))
        snapshotButton.bezelStyle = .rounded
        snapshotButton.frame = NSRect(
            x: 28, y: 202, width: max(160, ceil(snapshotButton.intrinsicContentSize.width)), height: 32)
        root.addSubview(snapshotButton)
        snapshotLabel.frame = NSRect(x: 212, y: 206, width: 334, height: 24)
        snapshotLabel.lineBreakMode = .byTruncatingMiddle
        root.addSubview(snapshotLabel)
        ControlLayout.align(snapshotLabel, with: snapshotButton)
        let clearSnapshot = snapshotClearButton
        clearSnapshot.target = target
        clearSnapshot.action = #selector(BuilderFormActions.clearSnapshot(_:))
        clearSnapshot.image = NSImage(
            systemSymbolName: "xmark.circle.fill", accessibilityDescription: builderIntl.removeStartupSnapshot
        )
        clearSnapshot.imagePosition = .imageOnly
        clearSnapshot.isBordered = false
        clearSnapshot.isHidden = true
        clearSnapshot.toolTip = builderIntl.removeSnapshotHint
        clearSnapshot.bezelStyle = .rounded
        clearSnapshot.frame = NSRect(x: 558, y: 206, width: 28, height: 24)
        root.addSubview(clearSnapshot)
        snapshotButton.toolTip = builderIntl.startupSnapshotHint
        for y: CGFloat in [190, 66] {
            let separator = NSBox(frame: NSRect(x: 28, y: y, width: 564, height: 1))
            separator.boxType = .separator
            root.addSubview(separator)
        }
    }

    func rebuildMounts(disks: [URL], target: BuilderFormActions) {
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
            choice.target = target
            choice.action = #selector(BuilderFormActions.mountChanged(_:))
            content.addSubview(choice)
            ControlLayout.align(label, with: choice)
            mountChoices.append(choice)
        }
        mountList.documentView = content
    }

    /// Captures UI values once; validation and side effects belong to domain/application services.
    func configuration(disks: [URL], icon: Data?, snapshot: URL?) throws -> PlayerBuildConfiguration {
        let mounts = mountChoices.enumerated().compactMap { index, choice -> DiskMount? in
            return choice.indexOfSelectedItem == 0
                ? nil
                : DiskMount(diskIndex: index, address: configuredDrives[choice.indexOfSelectedItem - 1])
        }
        return PlayerBuildConfiguration(
            name: try PlayerManifest.checkedName(appName.stringValue),
            disks: disks, bootSlot: [6, 5, 7][slot.indexOfSelectedItem], icon: icon, mounts: mounts,
            diskNames: diskNameFields.map { $0.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) },
            drives: configuredDrives, speed: EmulationSpeed.allCases[speed.indexOfSelectedItem],
            fullScreen: fullScreen.state == .on, startupSnapshot: snapshot,
            expansionMemoryKB: PlayerManifest.expansionMemoryChoices[memory.indexOfSelectedItem])
    }

    func displaySettings(_ document: BuilderPlayerDocument) {
        let manifest = document.manifest
        appName.stringValue =
            document.name
        for (index, count) in driveCounts.enumerated() {
            count.selectItem(
                at: manifest.drives.filter { $0.slot == [6, 5, 7][index] }.map { $0.drive + 1 }.max() ?? 0
            )
        }
        slot.selectItem(at: [6, 5, 7].firstIndex(of: manifest.bootSlot)!)
        speed.selectItem(
            at: EmulationSpeed.allCases.firstIndex(of: manifest.initialSpeed ?? .oneMHz)!)
    }

    func displayMedia(_ document: BuilderPlayerDocument, target: BuilderFormActions) {
        let manifest = document.manifest
        memory.selectItem(
            at: PlayerManifest.expansionMemoryChoices.firstIndex(of: manifest.expansionMemoryKB ?? 8192)!)
        fullScreen.state = manifest.startInFullScreen == true ? .on : .off
        memory.isEnabled = document.snapshot == nil
        speed.isEnabled = document.snapshot == nil
        snapshotLabel.stringValue =
            document.snapshot == nil ? builderIntl.normalStartup : builderIntl.bundledStartupSnapshot
        rebuildMounts(disks: document.disks, target: target)
        for index in document.disks.indices {
            diskNameFields[index].stringValue = manifest.diskName(at: index)
            let address = manifest.mounts.first { $0.diskIndex == index }?.address
            mountChoices[index].selectItem(
                at: address.flatMap { configuredDrives.firstIndex(of: $0) }.map { $0 + 1 } ?? 0)
        }
    }

    func displayBootReadiness(_ readiness: BootReadiness) {
        let explanation: String
        switch readiness {
        case .ready:
            bootLight.contentTintColor = .systemGreen
            explanation = builderIntl.bootReady
        case .missingDisk:
            bootLight.contentTintColor = .systemRed
            explanation = builderIntl.bootMissingDisk
        case .notBootable:
            bootLight.contentTintColor = .systemRed
            explanation = builderIntl.bootNotReady
        case .unknown:
            bootLight.contentTintColor = .systemOrange
            explanation = builderIntl.bootUnknown
        case .snapshot:
            bootLight.contentTintColor = .systemOrange
            explanation = builderIntl.bootSnapshot
        }
        bootLight.toolTip = explanation
        bootLight.setAccessibilityLabel(explanation)
    }
}
