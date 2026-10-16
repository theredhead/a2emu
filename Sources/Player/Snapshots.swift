import Cocoa

extension AppDelegate {
    var snapshotsDirectory: URL { supportDirectory.appendingPathComponent("Snapshots", isDirectory: true) }
    var currentDiskDirectory: URL { snapshotDiskDirectory ?? supportDirectory }

    /// Reuses the writable disk set already mounted by the persisted core configuration.
    func findSnapshotWorkingDisks() {
        let workingRoot = supportDirectory.appendingPathComponent("Snapshot Disks", isDirectory: true)
        let directories = Set(
            DriveAddress.all.compactMap { address -> URL? in
                guard let path = a2_snapshot_disk_path(Int32(address.slot), Int32(address.drive)) else {
                    return nil
                }
                return URL(fileURLWithPath: String(cString: path)).deletingLastPathComponent()
            })
        if directories.count == 1, let directory = directories.first,
            directory.deletingLastPathComponent() == workingRoot,
            UUID(uuidString: directory.lastPathComponent) != nil
        {
            snapshotDiskDirectory = directory
        }
    }

    func snapshotCore(_ operation: (UnsafePointer<CChar>?) -> Int32, at url: URL) throws {
        guard url.path.withCString({ operation($0) }) != 0 else {
            throw PlayerManifest.failure(String(cString: a2_snapshot_error()))
        }
    }

    /// Captures between emulation ticks. A package is visible only once every file has been written.
    func saveSnapshot(title: String) throws -> URL {
        guard emulatorStarted, let view = mainwin_info.mac_view else {
            throw PlayerManifest.failure("Start the emulator before saving a snapshot.")
        }
        let manager = FileManager.default
        try manager.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)
        let staging = snapshotsDirectory.appendingPathComponent(".saving-" + UUID().uuidString)
        defer { try? manager.removeItem(at: staging) }
        try manager.createDirectory(
            at: staging.appendingPathComponent("Disks"), withIntermediateDirectories: true)
        guard a2_snapshot_flush_disks() != 0 else {
            throw PlayerManifest.failure(String(cString: a2_snapshot_error()))
        }
        var mounts: [DiskMount] = []
        var sources = machine.diskFiles.map { currentDiskDirectory.appendingPathComponent($0) }
        for address in DriveAddress.all {
            if let path = a2_snapshot_disk_path(Int32(address.slot), Int32(address.drive)) {
                let source = URL(fileURLWithPath: String(cString: path))
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
        try snapshotCore(a2_snapshot_save, at: staging.appendingPathComponent(PlayerSnapshot.stateName))
        let preview = try view.saveScreenshot(in: staging)
        try manager.moveItem(at: preview, to: staging.appendingPathComponent(PlayerSnapshot.previewName))
        let snapshot = try PlayerSnapshot.finish(
            at: staging, title: title, gameName: PlayerManifest.displayName,
            disks: machine.diskFiles, mounts: mounts)
        let destination = snapshotsDirectory.appendingPathComponent(
            snapshot.id.uuidString + "." + PlayerSnapshot.fileExtension)
        try manager.moveItem(at: staging, to: destination)
        return destination
    }

    /// Restores into new writable disks. Failed disk-layout validation rolls back the previous machine.
    func restoreSnapshot(at url: URL) throws {
        let snapshot = try PlayerSnapshot.read(at: url)
        guard snapshot.diskFiles == machine.diskFiles else {
            throw PlayerManifest.failure("This snapshot belongs to a player with a different set of disks.")
        }
        let state = url.appendingPathComponent(PlayerSnapshot.stateName)
        try snapshotCore(a2_snapshot_validate, at: state)
        let manager = FileManager.default
        let working = supportDirectory.appendingPathComponent("Snapshot Disks", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try manager.createDirectory(at: working, withIntermediateDirectories: true)
        var committed = false
        defer { if !committed { try? manager.removeItem(at: working) } }
        for name in snapshot.diskFiles {
            try manager.copyItem(
                at: PlayerSnapshot.payload(name, at: url), to: working.appendingPathComponent(name))
        }
        guard a2_snapshot_flush_disks() != 0 else {
            throw PlayerManifest.failure(String(cString: a2_snapshot_error()))
        }
        let rollback = working.appendingPathComponent("Rollback.state")
        try snapshotCore(a2_snapshot_save, at: rollback)
        var oldMounts: [(DriveAddress, String)] = []
        for address in DriveAddress.all {
            if let path = a2_snapshot_disk_path(Int32(address.slot), Int32(address.drive)) {
                oldMounts.append((address, String(cString: path)))
            }
        }
        a2_snapshot_eject_disks()
        for mount in snapshot.mounts {
            working.appendingPathComponent(snapshot.diskFiles[mount.diskIndex]).path.withCString {
                insert_disk(Int32(mount.address.slot), Int32(mount.address.drive), $0, 0, nil, -1, 0)
            }
        }
        do {
            try snapshotCore(a2_snapshot_restore, at: state)
        } catch {
            let restoreError = error
            a2_snapshot_eject_disks()
            for (address, path) in oldMounts {
                path.withCString { insert_disk(Int32(address.slot), Int32(address.drive), $0, 0, nil, -1, 0) }
            }
            do {
                try snapshotCore(a2_snapshot_restore, at: rollback)
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
        a2_snapshot_reset_audio()
        snapshotDiskDirectory = working
        mountedImages = Dictionary(uniqueKeysWithValues: snapshot.mounts.map { ($0.address, $0.diskIndex) })
        updateDiskChecks()
        updateSpeedChecks()
        _ = config_write_config_kegs_file(0)
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
