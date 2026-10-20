import Cocoa

private let snapshotsIntl = SnapshotsIntl()

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
            throw PlayerManifest.failure(snapshotsIntl.startTheEmulatorBeforeSavingA)
        }
        let manager = FileManager.default
        try manager.createDirectory(at: snapshotsDirectory, withIntermediateDirectories: true)
        let staging = snapshotsDirectory.appendingPathComponent(".saving-" + UUID().uuidString)
        defer { try? manager.removeItem(at: staging) }
        try manager.createDirectory(
            at: staging.appendingPathComponent("Disks"), withIntermediateDirectories: true)
        try EmulatorCore.flushDisks()
        var mounts: [DiskMount] = []
        var sources = machine.diskFiles.map { diskURL(named: $0) }
        for address in DriveAddress.all {
            if let path = EmulatorCore.mountedDiskPath(slot: Int32(address.slot), drive: Int32(address.drive))
            {
                let source = URL(fileURLWithPath: path)
                guard let index = machine.diskFiles.firstIndex(of: source.lastPathComponent) else {
                    throw PlayerManifest.failure(
                        snapshotsIntl.thisSnapshotHasAMountedDisk)
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
            expansionMemoryKB: Int(EmulatorCore.expansionMemoryBytes / 1024),
            temporaryDiskFiles: machine.diskFiles.filter { temporaryDiskNames.contains($0) })
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

    /// A snapshot may retain additional session disks, or predate disks added to the library.
    func snapshotFitsDiskSet(_ snapshot: PlayerSnapshot) -> Bool {
        let sessionNames = temporaryDiskNames.union(snapshot.temporaryDiskFiles ?? [])
        let saved = snapshot.diskFiles.filter { !sessionNames.contains($0) }
        let current = machine.diskFiles.filter { !sessionNames.contains($0) }
        return !saved.isEmpty && !current.isEmpty
            && (current.starts(with: saved) || saved.starts(with: current))
    }

    /// Restores into new writable disks. Failed disk-layout validation rolls back the previous machine.
    func restoreSnapshot(at url: URL, applyAdditionalStartupMounts: Bool = false) throws {
        let snapshot = try PlayerSnapshot.read(at: url)
        guard snapshotFitsDiskSet(snapshot) else {
            throw PlayerManifest.failure(snapshotsIntl.thisSnapshotBelongsToAPlayer)
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
        // Disks imported after this checkpoint remain available without rewriting the saved snapshot.
        for name in machine.diskFiles where !snapshot.diskFiles.contains(name) {
            try manager.copyItem(
                at: diskURL(named: name),
                to: working.appendingPathComponent(name))
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
                    snapshotsIntl.recoveryFailure(
                        recoveryPath: working.path, errorDescription: error.localizedDescription))
            }
            throw restoreError
        }
        try? manager.removeItem(at: rollback)
        try? manager.removeItem(at: state)
        EmulatorCore.resetAudio()
        snapshotNeedsVideoRefresh = true
        mainWindowInfo.view?.showSnapshotPreview(at: url.appendingPathComponent(PlayerSnapshot.previewName))
        let extraNames = snapshot.diskFiles.filter { !machine.diskFiles.contains($0) }
        if !extraNames.isEmpty {
            var updated = machine!
            updated.diskFiles += extraNames
            if let labels = updated.diskNames { updated.diskNames = labels + extraNames }
            machine = updated
            temporaryDiskNames.formUnion(extraNames)
            for name in extraNames {
                temporaryDiskSavedHashes[name] = try? PlayerSnapshot.digest(
                    working.appendingPathComponent(name))
            }
        }
        for mount in snapshot.mounts where temporaryDiskNames.contains(snapshot.diskFiles[mount.diskIndex]) {
            if temporaryDrivePaths[mount.address] == nil {
                temporaryDrivePaths[mount.address] =
                    oldMounts.first {
                        $0.0 == mount.address
                            && !temporaryDiskNames.contains(URL(fileURLWithPath: $0.1).lastPathComponent)
                    }?.1 ?? ""
            }
        }
        for name in snapshot.diskFiles { temporaryDiskPaths.removeValue(forKey: name) }
        snapshotDiskDirectory = working
        addDiskMenus()
        mountedImages = Dictionary(
            uniqueKeysWithValues: snapshot.mounts.map {
                ($0.address, machine.diskFiles.firstIndex(of: snapshot.diskFiles[$0.diskIndex])!)
            })
        if applyAdditionalStartupMounts {
            for mount in machine.mounts where !snapshot.diskFiles.contains(machine.diskFiles[mount.diskIndex])
            {
                EmulatorCore.ejectDisk(slot: Int32(mount.address.slot), drive: Int32(mount.address.drive))
                EmulatorCore.mountDisk(
                    at: diskURL(named: machine.diskFiles[mount.diskIndex]), in: mount.address)
                mountedImages[mount.address] = mount.diskIndex
            }
        }
        updateDiskChecks()
        updateTemporaryMediaMenu()
        updateSpeedChecks()
        writePlayerConfiguration()
        committed = true
    }

    @objc func showSnapshots(_ sender: Any?) {
        guard emulatorStarted else { return }
        if let event = NSApp.currentEvent, event.type == .keyDown, event.isARepeat { return }
        if snapshotBrowser == nil { snapshotBrowser = SnapshotBrowser(player: self) }
        snapshotBrowser?.showWindow(nil)
        snapshotBrowser?.reload()
        snapshotBrowser?.window?.makeKeyAndOrderFront(nil)
    }
}
