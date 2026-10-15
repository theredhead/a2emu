import Foundation

/// Creates and replaces signed player bundles using a sibling staging directory.
struct PlayerExporter {
    /// Validates defaults, copies media into the template, and signs before moving to the destination.
    /// Throws on validation, file, or signing failure; the destination must not already exist.
    static func export(
        disks: [URL], slot: Int, template: URL, destination: URL, icon: Data? = nil,
        displayName: String? = nil, mounts: [DiskMount]? = nil, diskNames: [String]? = nil,
        availableDrives: [DriveAddress]? = nil, initialSpeed: EmulationSpeed = .oneMHz,
        startInFullScreen: Bool = false, bundleIdentifier: String? = nil, configurationRevision: String? = nil
    ) throws {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else {
            throw PlayerManifest.failure("That app already exists. Choose a new name or location.")
        }

        let appName = try PlayerManifest.checkedName(
            displayName ?? destination.deletingPathExtension().lastPathComponent)
        let names = disks.map { $0.lastPathComponent }
        guard Set(names).count == names.count else {
            throw PlayerManifest.failure("Each disk must have a different filename.")
        }

        var manifest = try PlayerManifest.make(
            disks: names, slot: slot, mounts: mounts, diskNames: diskNames, availableDrives: availableDrives,
            initialSpeed: initialSpeed, startInFullScreen: startInFullScreen)
        manifest.configurationRevision = configurationRevision
        try manifest.validate()
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
            throw PlayerManifest.failure("Could not sign the exported player.")
        }
        try manager.moveItem(at: staging, to: destination)
    }

    /// Reads and validates a player manifest and checks that its bundled disk images exist.
    static func read(app: URL) throws -> PlayerManifest {
        guard app.pathExtension.lowercased() == "app" else {
            throw PlayerManifest.failure("Choose an a2emu player app.")
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
                throw PlayerManifest.failure("This player is missing a bundled disk image.")
            }
        }
        return manifest
    }

    /// Rebuilds a player while retaining its bundle identifier and external saved-data location.
    /// If replacement fails after moving the original aside, attempts to restore the backup.
    static func update(
        app: URL, disks: [URL], slot: Int, icon: Data?, displayName: String, mounts: [DiskMount],
        diskNames: [String], availableDrives: [DriveAddress], initialSpeed: EmulationSpeed,
        startInFullScreen: Bool
    ) throws {
        _ = try read(app: app)
        let manager = FileManager.default
        let info =
            try PropertyListSerialization.propertyList(
                from: Data(contentsOf: app.appendingPathComponent("Contents/Info.plist")), format: nil)
            as? [String: Any]
        guard let identifier = info?["CFBundleIdentifier"] as? String else {
            throw PlayerManifest.failure("This player has no application identifier.")
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
            configurationRevision: UUID().uuidString)
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
