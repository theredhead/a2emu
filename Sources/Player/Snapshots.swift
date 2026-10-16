import Cocoa

extension AppDelegate {
    var snapshotsDirectory: URL { supportDirectory.appendingPathComponent("Snapshots", isDirectory: true) }
    var currentDiskDirectory: URL { snapshotDiskDirectory ?? supportDirectory }

    /// Reuses the writable disk set already mounted by the persisted core configuration.
    func findSnapshotWorkingDisks() {
        let workingRoot = supportDirectory.appendingPathComponent("Snapshot Disks", isDirectory: true)
        let directories = Set(
            DriveAddress.all.compactMap { address -> URL? in
                guard
                    let path = EmulatorCore.mountedDiskPath(
                        slot: Int32(address.slot), drive: Int32(address.drive))
                else {
                    return nil
                }
                return URL(fileURLWithPath: path).deletingLastPathComponent()
            })
        if directories.count == 1, let directory = directories.first,
            directory.deletingLastPathComponent() == workingRoot,
            UUID(uuidString: directory.lastPathComponent) != nil
        {
            snapshotDiskDirectory = directory
        }
    }

    /// Captures between emulation ticks. A package is visible only once every file has been written.
    func saveSnapshot(title: String) throws -> URL {
        guard emulatorStarted, let view = mainWindowInfo.view else {
            throw PlayerManifest.failure("Start the emulator before saving a snapshot.")
        }
        let manager = FileManager.default
        try manager.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)
        let staging = snapshotsDirectory.appendingPathComponent(".saving-" + UUID().uuidString)
        defer { try? manager.removeItem(at: staging) }
        try manager.createDirectory(
            at: staging.appendingPathComponent("Disks"), withIntermediateDirectories: true)
        try EmulatorCore.flushDisks()
        var mounts: [DiskMount] = []
        var sources = machine.diskFiles.map { currentDiskDirectory.appendingPathComponent($0) }
        for address in DriveAddress.all {
            if let path = EmulatorCore.mountedDiskPath(slot: Int32(address.slot), drive: Int32(address.drive))
            {
                let source = URL(fileURLWithPath: path)
                guard let index = machine.diskFiles.firstIndex(of: source.lastPathComponent) else {
                    throw PlayerManifest.failure(
                        "This snapshot has a mounted disk that is not part of this player.")
                }
                sources[index] = source
                mounts.append(DiskMount(diskIndex: index, address: address))
            }
        }
        for (index, source) in sources.enumerated() {
            try manager.copyItem(
                at: source, to: PlayerSnapshot.payload(machine.diskFiles[index], at: staging))
        }
        try EmulatorCore.saveSnapshot(at: staging.appendingPathComponent(PlayerSnapshot.stateName))
        let preview = try view.saveScreenshot(in: staging)
        try manager.moveItem(at: preview, to: staging.appendingPathComponent(PlayerSnapshot.previewName))
        let snapshot = try PlayerSnapshot.finish(
            at: staging, title: title, gameName: PlayerManifest.displayName,
            disks: machine.diskFiles, mounts: mounts, compress: true,
            expansionMemoryKB: Int(EmulatorCore.expansionMemoryBytes / 1024))
        let destination = snapshotsDirectory.appendingPathComponent(
            snapshot.fileName)
        try manager.moveItem(at: staging, to: destination)
        setSnapshotFinderIcon(at: destination)
        return destination
    }

    /// Gives the package a useful Finder thumbnail without changing its validated payloads.
    func setSnapshotFinderIcon(at url: URL) {
        if let image = NSImage(contentsOf: url.appendingPathComponent(PlayerSnapshot.previewName)) {
            NSWorkspace.shared.setIcon(image, forFile: url.path, options: [])
        }
    }

    /// Invalidates derived video caches on the next tick without changing the saved machine format.
    func refreshSnapshotDisplayIfNeeded() {
        guard snapshotNeedsVideoRefresh else { return }
        snapshotNeedsVideoRefresh = false
        EmulatorCore.invalidateVideo()
    }

    /// Restores into new writable disks. Failed disk-layout validation rolls back the previous machine.
    func restoreSnapshot(at url: URL) throws {
        let snapshot = try PlayerSnapshot.read(at: url)
        guard snapshot.diskFiles == machine.diskFiles else {
            throw PlayerManifest.failure("This snapshot belongs to a player with a different set of disks.")
        }
        let manager = FileManager.default
        let working = supportDirectory.appendingPathComponent("Snapshot Disks", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: working, withIntermediateDirectories: true)
        var committed = false
        defer { if !committed { try? manager.removeItem(at: working) } }
        for name in snapshot.diskFiles {
            try snapshot.extract(name, from: url, to: working.appendingPathComponent(name))
        }
        let state = working.appendingPathComponent("Restore.state")
        try snapshot.extract(PlayerSnapshot.stateName, from: url, to: state)
        try EmulatorCore.validateSnapshot(at: state)
        try EmulatorCore.flushDisks()
        let rollback = working.appendingPathComponent("Rollback.state")
        try EmulatorCore.saveSnapshot(at: rollback)
        var oldMounts: [(DriveAddress, String)] = []
        for address in DriveAddress.all {
            if let path = EmulatorCore.mountedDiskPath(slot: Int32(address.slot), drive: Int32(address.drive))
            {
                oldMounts.append((address, path))
            }
        }
        EmulatorCore.ejectAllDisks()
        for mount in snapshot.mounts {
            EmulatorCore.mountDisk(
                at: working.appendingPathComponent(snapshot.diskFiles[mount.diskIndex]), in: mount.address)
        }
        do {
            try EmulatorCore.restoreSnapshot(at: state)
        } catch {
            let restoreError = error
            EmulatorCore.ejectAllDisks()
            for (address, path) in oldMounts {
                EmulatorCore.mountDisk(at: URL(fileURLWithPath: path), in: address)
            }
            do {
                try EmulatorCore.restoreSnapshot(at: rollback)
            } catch {
                // Retain the rollback and disks for recovery if the core cannot resume safely.
                committed = true
                setEmulationPaused(true, reason: "Snapshot recovery failed")
                throw PlayerManifest.failure(
                    "Could not restore the snapshot or recover the previous machine. The emulator is paused. "
                        + "Recovery data: \(working.path). \(error.localizedDescription)")
            }
            throw restoreError
        }
        try? manager.removeItem(at: rollback)
        try? manager.removeItem(at: state)
        EmulatorCore.resetAudio()
        snapshotNeedsVideoRefresh = true
        mainWindowInfo.view?.showSnapshotPreview(at: url.appendingPathComponent(PlayerSnapshot.previewName))
        snapshotDiskDirectory = working
        mountedImages = Dictionary(uniqueKeysWithValues: snapshot.mounts.map { ($0.address, $0.diskIndex) })
        updateDiskChecks()
        updateSpeedChecks()
        EmulatorCore.writeConfiguration()
        committed = true
    }

    @objc func showSnapshots(_ sender: Any?) {
        guard emulatorStarted else { return }
        if snapshotBrowser == nil { snapshotBrowser = SnapshotBrowser(player: self) }
        snapshotBrowser?.reload()
        snapshotBrowser?.showWindow(nil)
        snapshotBrowser?.window?.makeKeyAndOrderFront(nil)
    }
}
