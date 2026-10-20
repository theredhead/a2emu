import Cocoa
import UniformTypeIdentifiers

private let diskDropIntl = PlayerIntl()
private let diskDropCommonIntl = CommonIntl()

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

extension AppDelegate {
    func diskURL(named name: String) -> URL {
        return temporaryDiskPaths[name] ?? currentDiskDirectory.appendingPathComponent(name)
    }

    func refreshMountedImagesFromCore() {
        mountedImages = [:]
        for address in machine.drives {
            if let path = EmulatorCore.mountedDiskPath(
                slot: Int32(address.slot), drive: Int32(address.drive)),
                let index = machine.diskFiles.firstIndex(of: URL(fileURLWithPath: path).lastPathComponent)
            {
                mountedImages[address] = index
            }
        }
    }

    /// Saves persistent drive choices while leaving session-only mounts out of config.kegs.
    func writePlayerConfiguration() {
        EmulatorCore.writeConfiguration()
        guard !temporaryDiskNames.isEmpty else { return }
        let config = supportDirectory.appendingPathComponent("config.kegs")
        guard let text = try? String(contentsOf: config, encoding: .utf8) else { return }
        try? persistentDiskConfiguration(text).write(to: config, atomically: true, encoding: .utf8)
    }

    func persistentDiskConfiguration(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines).compactMap { line -> String? in
            let parts = line.components(separatedBy: "=")
            guard parts.count >= 2 else { return line }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let path = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
            guard key.hasPrefix("s"), key.count >= 4,
                let slot = Int(key.dropFirst().prefix(1)), let drive = Int(key.dropFirst(3)),
                temporaryDiskNames.contains(URL(fileURLWithPath: path).lastPathComponent)
            else { return line }
            let address = DriveAddress(slot: slot, drive: drive - 1)
            guard let previous = temporaryDrivePaths[address], !previous.isEmpty else { return nil }
            return "\(key) = \(previous)"
        }
        return lines.joined(separator: "\n")
    }

    /// Imports each image into a free compatible drive, or asks which occupied drive to replace.
    /// Ordinary drops use private session copies; Option-drop also updates the portable app bundle.
    @discardableResult
    func mountDroppedDisks(
        _ urls: [URL], permanently: Bool,
        chooseDrive: ((URL, [DriveAddress]) -> DriveAddress?)? = nil,
        rename: ((String) -> String?)? = nil, app: URL = Bundle.main.bundleURL,
        sign: ((URL) throws -> Void)? = nil
    ) throws -> Bool {
        let manager = FileManager.default
        if emulatorStarted { refreshMountedImagesFromCore() }
        let extensions = ["woz", "dsk", "do", "po", "2mg", "2img", "hdv", "nib"]
        for source in urls {
            guard extensions.contains(source.pathExtension.lowercased()),
                (try source.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true
            else { throw PlayerManifest.failure(diskDropIntl.invalidDiskDrop) }
            let slot = DiskImageDevice.detect(source).slot
            let compatible = machine.drives.filter { $0.slot == slot }.sorted { $0.drive < $1.drive }
            guard !compatible.isEmpty else {
                throw PlayerManifest.failure(
                    diskDropIntl.noCompatibleDrive(filename: source.lastPathComponent))
            }
            let address: DriveAddress
            if let free = compatible.first(where: { mountedImages[$0] == nil }) {
                address = free
            } else if let chooseDrive = chooseDrive {
                guard let selected = chooseDrive(source, compatible) else { return false }
                guard compatible.contains(selected) else { return false }
                address = selected
            } else {
                guard let selected = chooseDropDrive(source, compatible: compatible) else { return false }
                address = selected
            }
            var name = source.lastPathComponent
            while !PlayerSnapshot.safeName(name) || machine.diskFiles.contains(name)
                || manager.fileExists(atPath: supportDirectory.appendingPathComponent(name).path)
                || manager.fileExists(atPath: currentDiskDirectory.appendingPathComponent(name).path)
                || (name as NSString).pathExtension.lowercased() != source.pathExtension.lowercased()
            {
                let replacement = rename?(name) ?? (rename == nil ? requestDiskImportName(name) : nil)
                guard let replacement = replacement else { return false }
                name = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
                if (name as NSString).pathExtension.isEmpty {
                    name += "." + source.pathExtension.lowercased()
                }
            }
            var updated = machine!
            updated.diskFiles.append(name)
            if let labels = updated.diskNames { updated.diskNames = labels + [name] }
            try updated.validate()
            if temporaryDiskDirectory == nil {
                let directory = manager.temporaryDirectory.appendingPathComponent(
                    "a2-disks-" + UUID().uuidString)
                try manager.createDirectory(at: directory, withIntermediateDirectories: true)
                temporaryDiskDirectory = directory
            }
            let staged = temporaryDiskDirectory!.appendingPathComponent(name)
            try manager.copyItem(at: source, to: staged)
            var committed = false
            defer { if !committed { try? manager.removeItem(at: staged) } }
            if permanently {
                let destination = supportDirectory.appendingPathComponent(name)
                try manager.copyItem(at: staged, to: destination)
                do {
                    if currentDiskDirectory != supportDirectory {
                        try manager.copyItem(
                            at: staged, to: currentDiskDirectory.appendingPathComponent(name))
                    }
                    try persistDroppedDisk(staged, name: name, in: address, app: app, sign: sign)
                } catch {
                    try? manager.removeItem(at: destination)
                    if currentDiskDirectory != supportDirectory {
                        try? manager.removeItem(at: currentDiskDirectory.appendingPathComponent(name))
                    }
                    throw error
                }
                // Former saved-library images are now inside the portable app, too.
                try? manager.removeItem(at: supportDirectory.appendingPathComponent("Imported-Disks.json"))
                temporaryDrivePaths.removeValue(forKey: address)
            } else {
                if temporaryDrivePaths[address] == nil {
                    temporaryDrivePaths[address] =
                        mountedImages[address].map {
                            diskURL(named: machine.diskFiles[$0]).path
                        } ?? ""
                }
                temporaryDiskNames.insert(name)
                temporaryDiskPaths[name] = staged
                temporaryDiskOriginalPaths[name] = source
                temporaryDiskSavedHashes[name] = try PlayerSnapshot.digest(staged)
            }
            machine = updated
            let index = machine.diskFiles.count - 1
            if emulatorStarted {
                EmulatorCore.ejectDisk(slot: Int32(address.slot), drive: Int32(address.drive))
                EmulatorCore.mountDisk(at: diskURL(named: name), in: address)
            }
            var mounted = mountedImages
            mounted[address] = index
            addDiskMenus()
            mountedImages = mounted
            updateDiskChecks()
            updateTemporaryMediaMenu()
            if emulatorStarted { writePlayerConfiguration() }
            committed = true
        }
        return !urls.isEmpty
    }

    func changedTemporaryDisks() throws -> [String] {
        guard !temporaryDiskNames.isEmpty else { return [] }
        if emulatorStarted { try EmulatorCore.flushDisks() }
        return try machine.diskFiles.filter { name in
            guard temporaryDiskNames.contains(name) else { return false }
            return try PlayerSnapshot.digest(diskURL(named: name)) != temporaryDiskSavedHashes[name]
        }
    }

    func updateTemporaryMediaMenu() {
        temporaryMediaHaveChanges = (try? changedTemporaryDisks().isEmpty) != true
        if let menu = playerMenu?.submenu(.disks) { playerMenu?.refresh(menu) }
    }

    @objc func saveTemporaryMedia(_ sender: Any?) {
        setDialogOpen(true, reason: "Save Temporary Media")
        defer { setDialogOpen(false, reason: "Save Temporary Media") }
        do { _ = try saveTemporaryDisks() } catch { showTemporaryMediaSaveError(error) }
    }

    /// Writes changed session copies back to their sources, asking for another destination only on failure.
    @discardableResult
    func saveTemporaryDisks(
        chooseDestination: ((String) -> URL?)? = nil,
        write: ((Data, URL) throws -> Void)? = nil
    ) throws -> Bool {
        let changed = try changedTemporaryDisks()
        for name in changed {
            let source = diskURL(named: name)
            let data = try Data(contentsOf: source)
            let writeImage: (URL) throws -> Void = { destination in
                let mountedDestination = self.mountedImages.values.contains {
                    self.diskURL(named: self.machine.diskFiles[$0]).standardizedFileURL
                        == destination.standardizedFileURL
                }
                guard destination.standardizedFileURL != source.standardizedFileURL, !mountedDestination
                else {
                    throw PlayerManifest.failure(diskDropIntl.invalidDiskDrop)
                }
                if let write = write {
                    try write(data, destination)
                } else {
                    try data.write(to: destination, options: .atomic)
                }
            }
            var saved = false
            if let original = temporaryDiskOriginalPaths[name] {
                do {
                    try writeImage(original)
                    saved = true
                } catch { saved = false }
            }
            if !saved {
                let destination: URL?
                if let chooseDestination = chooseDestination {
                    destination = chooseDestination(name)
                } else {
                    let panel = NSSavePanel()
                    panel.title = diskDropIntl.saveTemporaryMediaElsewhere
                    panel.nameFieldStringValue = name
                    panel.allowedContentTypes = [
                        UTType(filenameExtension: (name as NSString).pathExtension) ?? .data
                    ]
                    destination = panel.runModal() == .OK ? panel.url : nil
                }
                guard let destination = destination else {
                    updateTemporaryMediaMenu()
                    return false
                }
                try writeImage(destination)
                temporaryDiskOriginalPaths[name] = destination
            }
            temporaryDiskSavedHashes[name] = try PlayerSnapshot.digest(source)
        }
        updateTemporaryMediaMenu()
        return true
    }

    enum TemporaryMediaQuitChoice { case save, discard, cancel }

    func confirmTemporaryMediaQuit(
        choose: (([String]) -> TemporaryMediaQuitChoice)? = nil
    ) throws -> Bool {
        let changed = try changedTemporaryDisks()
        guard !changed.isEmpty else { return true }
        let choice: TemporaryMediaQuitChoice
        if let choose = choose {
            choice = choose(changed)
        } else {
            let alert = PlayerDiskAlert()
            alert.messageText = diskDropIntl.unsavedTemporaryMedia
            alert.informativeText = diskDropIntl.saveTemporaryMediaBeforeQuitting
            alert.addButton(withTitle: diskDropCommonIntl.save)
            alert.addButton(withTitle: diskDropIntl.discardTemporaryChanges)
            alert.addButton(withTitle: diskDropCommonIntl.cancel)
            switch alert.runModal() {
            case .alertFirstButtonReturn: choice = .save
            case .alertSecondButtonReturn: choice = .discard
            default: choice = .cancel
            }
        }
        switch choice {
        case .save: return try saveTemporaryDisks()
        case .discard: return true
        case .cancel: return false
        }
    }

    func showTemporaryMediaSaveError(_ error: Error) {
        let alert = PlayerDiskAlert()
        alert.messageText = diskDropIntl.couldNotSaveTemporaryMedia
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private func chooseDropDrive(_ source: URL, compatible: [DriveAddress]) -> DriveAddress? {
        let alert = PlayerDiskAlert()
        alert.messageText = diskDropIntl.chooseDiskDrive
        alert.informativeText = diskDropIntl.replaceMountedDisk(filename: source.lastPathComponent)
        alert.addButton(withTitle: diskDropIntl.ejectAndMount)
        alert.addButton(withTitle: diskDropCommonIntl.cancel)
        let choices = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 420, height: 28))
        choices.addItems(
            withTitles: compatible.map { address in
                guard let index = mountedImages[address] else { return address.label }
                return "\(address.label) — \(machine.diskName(at: index))"
            })
        alert.accessoryView = choices
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return compatible[choices.indexOfSelectedItem]
    }

    /// Stages and signs a replacement app before swapping it into place; the running executable is untouched.
    private func persistDroppedDisk(
        _ source: URL, name: String, in address: DriveAddress, app: URL,
        sign: ((URL) throws -> Void)?
    ) throws {
        let manager = FileManager.default
        let stage = app.deletingLastPathComponent().appendingPathComponent(
            ".a2-disk-" + UUID().uuidString + ".app")
        let backup = app.deletingLastPathComponent().appendingPathComponent(
            ".a2-old-" + UUID().uuidString + ".app")
        defer { try? manager.removeItem(at: stage) }
        try manager.copyItem(at: app, to: stage)
        let resources = stage.appendingPathComponent("Contents/Resources")
        let manifestURL = resources.appendingPathComponent("Player.json")
        let original = try JSONDecoder().decode(PlayerManifest.self, from: Data(contentsOf: manifestURL))
        var names = machine.diskFiles.filter { !temporaryDiskNames.contains($0) }
        names.append(name)
        for filename in names {
            let destination = resources.appendingPathComponent(filename)
            if !manager.fileExists(atPath: destination.path) {
                try manager.copyItem(
                    at: filename == name ? source : diskURL(named: filename), to: destination)
            }
        }
        let labels = names.map { filename -> String in
            guard let index = machine.diskFiles.firstIndex(of: filename) else { return filename }
            return machine.diskName(at: index)
        }
        var mounts = original.mounts.filter { $0.address != address }
        mounts.append(DiskMount(diskIndex: names.count - 1, address: address))
        guard
            var json = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any]
        else {
            throw PlayerManifest.failure(diskDropIntl.invalidDiskDrop)
        }
        json["diskFiles"] = names
        json["diskNames"] = labels
        json["initialMounts"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(mounts))
        // Keep RAM, speed, ROM/BRAM, startup snapshot and drive settings as exported.
        let data = try JSONSerialization.data(withJSONObject: json)
        try JSONDecoder().decode(PlayerManifest.self, from: data).validate()
        try data.write(to: manifestURL, options: .atomic)
        if let sign = sign {
            try sign(stage)
        } else {
            for arguments in [
                ["--force", "--sign", "-", stage.path], ["--verify", "--deep", "--strict", stage.path],
            ] {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
                process.arguments = arguments
                let output = Pipe()
                process.standardOutput = output
                process.standardError = output
                try process.run()
                let diagnostic = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else {
                    throw PlayerManifest.failure(
                        String(data: diagnostic, encoding: .utf8) ?? diskDropIntl.invalidDiskDrop)
                }
            }
        }
        try manager.moveItem(at: app, to: backup)
        do { try manager.moveItem(at: stage, to: app) } catch {
            try? manager.moveItem(at: backup, to: app)
            throw error
        }
        try? manager.removeItem(at: backup)
    }
}
