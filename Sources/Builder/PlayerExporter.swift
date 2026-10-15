import Foundation
struct PlayerExporter {
    static func export(disks: [URL], slot: Int, template: URL, destination: URL, icon: Data? = nil, displayName: String? = nil, mounts: [DiskMount]? = nil, diskNames: [String]? = nil, availableDrives: [DriveAddress]? = nil, initialSpeed: EmulationSpeed = .oneMHz, startInFullScreen: Bool = false) throws {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else { throw PlayerManifest.failure("That app already exists. Choose a new name or location.") }
        let appName = try PlayerManifest.checkedName(displayName ?? destination.deletingPathExtension().lastPathComponent)
        let names = disks.map { $0.lastPathComponent }
        guard Set(names).count == names.count else { throw PlayerManifest.failure("Each disk must have a different filename.") }
        let manifest = try PlayerManifest.make(disks: names, slot: slot, mounts: mounts, diskNames: diskNames, availableDrives: availableDrives, initialSpeed: initialSpeed, startInFullScreen: startInFullScreen)
        try manifest.validate()
        let staging = destination.deletingLastPathComponent().appendingPathComponent(".a2-export-\(UUID().uuidString).app")
        defer { try? manager.removeItem(at: staging) }
        try manager.copyItem(at: template, to: staging)
        let resources = staging.appendingPathComponent("Contents/Resources")
        let oldManifest = resources.appendingPathComponent("Player.json")
        if let old = try? JSONDecoder().decode(PlayerManifest.self, from: Data(contentsOf: oldManifest)) {
            for name in old.diskFiles { try? manager.removeItem(at: resources.appendingPathComponent(name)) }
        }
        for disk in disks { try manager.copyItem(at: disk, to: resources.appendingPathComponent(disk.lastPathComponent)) }
        try JSONEncoder().encode(manifest).write(to: oldManifest, options: .atomic)
        let plist = staging.appendingPathComponent("Contents/Info.plist")
        var info = try PropertyListSerialization.propertyList(from: Data(contentsOf: plist), format: nil) as! [String: Any]
        info["CFBundleName"] = appName
        info["CFBundleDisplayName"] = appName
        info["CFBundleIdentifier"] = "nl.theredhead.a2emu-player." + PlayerManifest.normalizedName(disks[0].deletingPathExtension().lastPathComponent)
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0).write(to: plist, options: .atomic)
        if let icon = icon {
            try icon.write(to: resources.appendingPathComponent("PlayerIcon.png"), options: .atomic)
            try IconEncoder.writeICNS(png: icon, destination: resources.appendingPathComponent("Player.icns"))
        }
        let signing = Process()
        signing.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        signing.arguments = ["--force", "--sign", "-", staging.path]
        try signing.run(); signing.waitUntilExit()
        guard signing.terminationStatus == 0 else { throw PlayerManifest.failure("Could not sign the exported player.") }
        try manager.moveItem(at: staging, to: destination)
    }
}
