import Foundation

private let diskDropIntl = PlayerIntl()

/// Owns signed portable-bundle replacement and rollback without exposing filesystem staging to the UI.
struct PortableDiskWriter {
    /// Stages and signs a replacement app before swapping it into place; the running executable is untouched.
    func persist(
        _ source: URL, name: String, in address: DriveAddress, app: URL,
        manifest: PlayerManifest, temporaryNames: Set<String>, resolveDisk: (String) -> URL,
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
        var names = manifest.diskFiles.filter { !temporaryNames.contains($0) }
        names.append(name)
        for filename in names {
            let destination = resources.appendingPathComponent(filename)
            if !manager.fileExists(atPath: destination.path) {
                try manager.copyItem(
                    at: filename == name ? source : resolveDisk(filename), to: destination)
            }
        }

        let labels = names.map { filename -> String in
            guard let index = manifest.diskFiles.firstIndex(of: filename) else { return filename }
            return manifest.diskName(at: index)
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
