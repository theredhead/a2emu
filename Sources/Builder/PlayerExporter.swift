import Foundation

private let playerExporterIntl = PlayerExporterIntl()

/// Creates and replaces signed player bundles using a sibling staging directory.
struct PlayerExporter {
    /// Validates defaults, copies media into the template, and signs before moving to the destination.
    /// Throws on validation, file, or signing failure; the destination must not already exist.
    static func export(
        disks: [URL], slot: Int, template: URL, destination: URL, icon: Data? = nil,
        displayName: String? = nil, mounts: [DiskMount]? = nil, diskNames: [String]? = nil,
        availableDrives: [DriveAddress]? = nil, initialSpeed: EmulationSpeed = .oneMHz,
        startInFullScreen: Bool = false, bundleIdentifier: String? = nil,
        configurationRevision: String? = nil,
        startupSnapshot: URL? = nil, expansionMemoryKB: Int = 8192
    ) throws {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else {
            throw PlayerManifest.failure(playerExporterIntl.thatAppAlreadyExistsChooseA)
        }

        let appName = try PlayerManifest.checkedName(
            displayName ?? destination.deletingPathExtension().lastPathComponent)
        let names = disks.map { $0.lastPathComponent }
        guard Set(names).count == names.count else {
            throw PlayerManifest.failure(playerExporterIntl.eachDiskMustHaveADifferent)
        }

        var manifest = try PlayerManifest.make(
            disks: names, slot: slot, mounts: mounts, diskNames: diskNames, availableDrives: availableDrives,
            initialSpeed: initialSpeed, startInFullScreen: startInFullScreen,
            expansionMemoryKB: expansionMemoryKB)
        // A fresh export may reuse this game's saved-data directory. Apply its new
        // startup defaults once, just as an update does, then preserve player edits.
        manifest.configurationRevision = configurationRevision ?? UUID().uuidString
        manifest.startupSnapshot = startupSnapshot != nil
        try manifest.validate()
        if let snapshotURL = startupSnapshot {
            let snapshot = try PlayerSnapshot.read(at: snapshotURL)
            guard names.starts(with: snapshot.diskFiles),
                snapshot.mounts.allSatisfy({ manifest.drives.contains($0.address) })
            else {
                throw PlayerManifest.failure(
                    playerExporterIntl.theStartupSnapshotMustUseThis)
            }
            manifest.expansionMemoryKB = try snapshot.capturedExpansionMemoryKB(at: snapshotURL)
            try manifest.validate()
            try PlayerSnapshot.checkCore(at: snapshotURL, template: template)
        }
        let staging = destination.deletingLastPathComponent().appendingPathComponent(
            ".a2-export-\(UUID().uuidString).app")
        defer { try? manager.removeItem(at: staging) }
        try manager.copyItem(at: template, to: staging)
        let resources = staging.appendingPathComponent("Contents/Resources")
        let oldManifest = resources.appendingPathComponent("Player.json")
        if let old = try? JSONDecoder().decode(PlayerManifest.self, from: Data(contentsOf: oldManifest)) {
            for name in old.diskFiles {
                try? manager.removeItem(at: resources.appendingPathComponent(name))
            }
        }
        let bundledSnapshot = resources.appendingPathComponent("Startup.a2snapshot")
        if manager.fileExists(atPath: bundledSnapshot.path) { try manager.removeItem(at: bundledSnapshot) }
        if let snapshot = startupSnapshot {
            try manager.copyItem(at: snapshot, to: bundledSnapshot)
            let finderIcon = bundledSnapshot.appendingPathComponent("Icon\r")
            if manager.fileExists(atPath: finderIcon.path) { try manager.removeItem(at: finderIcon) }
            // Finder thumbnails belong to standalone snapshots; resource forks cannot be code signed.
            let clean = Process()
            clean.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            clean.arguments = ["-cr", bundledSnapshot.path]
            try clean.run()
            clean.waitUntilExit()
            guard clean.terminationStatus == 0 else {
                throw PlayerManifest.failure(playerExporterIntl.couldNotPrepareTheStartupSnapshot)
            }
        }
        for disk in disks {
            try manager.copyItem(at: disk, to: resources.appendingPathComponent(disk.lastPathComponent))
        }
        try JSONEncoder().encode(manifest).write(to: oldManifest, options: .atomic)
        let plist = staging.appendingPathComponent("Contents/Info.plist")
        var info =
            try PropertyListSerialization.propertyList(from: Data(contentsOf: plist), format: nil)
            as! [String: Any]
        info["CFBundleName"] = appName
        info["CFBundleDisplayName"] = appName
        info["CFBundleIdentifier"] =
            bundleIdentifier ?? "nl.theredhead.a2emu-player."
            + PlayerManifest.normalizedName(disks[0].deletingPathExtension().lastPathComponent)
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(
            to: plist, options: .atomic)
        if let icon = icon {
            try icon.write(to: resources.appendingPathComponent("PlayerIcon.png"), options: .atomic)
            try IconEncoder.writeICNS(png: icon, destination: resources.appendingPathComponent("Player.icns"))
        }

        let signing = Process()
        signing.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        signing.arguments = ["--force", "--sign", "-", staging.path]
        try signing.run()
        signing.waitUntilExit()
        guard signing.terminationStatus == 0 else {
            throw PlayerManifest.failure(playerExporterIntl.couldNotSignTheExportedPlayer)
        }
        try manager.moveItem(at: staging, to: destination)
    }

    /// Reads and validates a player manifest and checks that its bundled disk images exist.
    static func read(app: URL) throws -> PlayerManifest {
        guard app.pathExtension.lowercased() == "app" else {
            throw PlayerManifest.failure(playerExporterIntl.chooseAnA2EmuPlayerApp)
        }

        let manifest = try JSONDecoder().decode(
            PlayerManifest.self,
            from: Data(contentsOf: app.appendingPathComponent("Contents/Resources/Player.json")))
        try manifest.validate()
        for name in manifest.diskFiles {
            guard
                FileManager.default.fileExists(
                    atPath: app.appendingPathComponent("Contents/Resources").appendingPathComponent(name).path
                )
            else {
                throw PlayerManifest.failure(playerExporterIntl.thisPlayerIsMissingABundled)
            }
        }
        if manifest.startupSnapshot == true {
            let snapshotURL = app.appendingPathComponent("Contents/Resources/Startup.a2snapshot")
            let snapshot = try PlayerSnapshot.read(at: snapshotURL)
            guard manifest.diskFiles.starts(with: snapshot.diskFiles) else {
                throw PlayerManifest.failure(playerExporterIntl.theBundledStartupSnapshotUsesDifferent)
            }
            try PlayerSnapshot.checkCore(at: snapshotURL, template: app)
        }
        return manifest
    }

    /// Rebuilds a player while retaining its bundle identifier and external saved-data location.
    /// If replacement fails after moving the original aside, attempts to restore the backup.
    static func update(
        app: URL, disks: [URL], slot: Int, icon: Data?, displayName: String, mounts: [DiskMount],
        diskNames: [String], availableDrives: [DriveAddress], initialSpeed: EmulationSpeed,
        startInFullScreen: Bool, startupSnapshot: URL? = nil, expansionMemoryKB: Int = 8192
    ) throws {
        _ = try read(app: app)
        let manager = FileManager.default
        let info =
            try PropertyListSerialization.propertyList(
                from: Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")), format: nil)
            as? [String: Any]
        guard let identifier = info?["CFBundleIdentifier"] as? String else {
            throw PlayerManifest.failure(playerExporterIntl.thisPlayerHasNoApplicationIdentifier)
        }

        let temporary = app.deletingLastPathComponent().appendingPathComponent(
            ".a2-update-\(UUID().uuidString).app")
        let backup = app.deletingLastPathComponent().appendingPathComponent(
            ".a2-backup-\(UUID().uuidString).app")
        defer { try? manager.removeItem(at: temporary) }
        let runtime = Bundle.main.resourceURL?.appendingPathComponent("PlayerTemplate.app")
        let template = runtime.flatMap { manager.fileExists(atPath: $0.path) ? $0 : nil } ?? app
        try export(
            disks: disks, slot: slot, template: template, destination: temporary, icon: icon,
            displayName: displayName, mounts: mounts, diskNames: diskNames, availableDrives: availableDrives,
            initialSpeed: initialSpeed, startInFullScreen: startInFullScreen, bundleIdentifier: identifier,
            configurationRevision: UUID().uuidString, startupSnapshot: startupSnapshot,
            expansionMemoryKB: expansionMemoryKB)
        try manager.moveItem(at: app, to: backup)
        do {
            try manager.moveItem(at: temporary, to: app)
        } catch {
            try? manager.moveItem(at: backup, to: app)
            throw error
        }
        try? manager.removeItem(at: backup)
    }
}
