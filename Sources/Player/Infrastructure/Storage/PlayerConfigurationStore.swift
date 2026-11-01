import Foundation

/// Applies each export revision once while preserving the user's saved core settings and on-disk encoding.
struct PlayerConfigurationStore {
    let manager: FileManager

    init(manager: FileManager = .default) { self.manager = manager }

    func prepare(manifest: PlayerManifest, rom: URL, directory: URL) throws -> URL {
        let config = directory.appendingPathComponent("config.kegs")
        let settings = """
            \(manifest.mounts.map { "s\($0.address.slot)d\($0.address.drive + 1) = \(directory.appendingPathComponent(manifest.diskFiles[$0.diskIndex]).path)" }.joined(separator: "\n"))
            \(manifest.batteryConfiguration)
            g_cfg_rom_path = \(rom.path)
            g_limit_speed = \((manifest.initialSpeed ?? .oneMHz).rawValue)
            g_mem_size_exp = \((manifest.expansionMemoryKB ?? 8192) * 1024)
            g_zip_speed_mhz = 8
            g_status_enable = 0
            g_config_kegs_auto_update = 0
            """
        if manager.fileExists(atPath: config.path) {
            let previous = try String(contentsOf: config, encoding: .utf8)
            let revisionFile = directory.appendingPathComponent("Applied-Defaults.txt")
            let applied = try? String(contentsOf: revisionFile, encoding: .utf8)
            let changed = manifest.configurationRevision != nil && applied != manifest.configurationRevision
            let lines = previous.components(separatedBy: .newlines).filter {
                let line = $0.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("g_cfg_rom_path =") {
                    return false
                }
                guard changed else {
                    return true
                }
                return !line.hasPrefix("bram1[") && !line.hasPrefix("bram3[")
                    && !line.hasPrefix("g_limit_speed =") && !line.hasPrefix("g_zip_speed_mhz =")
                    && !line.hasPrefix("g_mem_size_exp =")
                    && line.range(of: "^s[567]d[0-9]+\\s*=", options: .regularExpression) == nil
            }

            let updated = changed ? settings : "g_cfg_rom_path = \(rom.path)"
            try (lines.joined(separator: "\n") + "\n" + updated + "\n").write(
                to: config, atomically: true, encoding: .utf8)
        } else {
            try (settings + "\n").write(to: config, atomically: true, encoding: .utf8)
        }
        if let revision = manifest.configurationRevision {
            try revision.write(
                to: directory.appendingPathComponent("Applied-Defaults.txt"), atomically: true,
                encoding: .utf8)
        }
        return config
    }

    func mounts(manifest: PlayerManifest, directory: URL) -> [DriveAddress: Int] {
        var mounts: [DriveAddress: Int] = [:]
        if let settings = try? String(
            contentsOf: directory.appendingPathComponent("config.kegs"), encoding: .utf8)
        {
            for line in settings.components(separatedBy: .newlines) {
                let parts = line.components(separatedBy: "=")
                guard parts.count >= 2 else {
                    continue
                }

                let key = parts[0].trimmingCharacters(in: .whitespaces)
                guard key.hasPrefix("s"), key.count >= 4, let slot = Int(key.dropFirst().prefix(1)),
                    let drive = Int(key.dropFirst(3))
                else {
                    continue
                }

                let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                guard !value.hasPrefix("#"),
                    let index = manifest.diskFiles.firstIndex(of: (value as NSString).lastPathComponent)
                else {
                    continue
                }

                let address = DriveAddress(slot: slot, drive: drive - 1)
                if DriveAddress.all.contains(address) {
                    mounts[address] = index
                }
            }
        }

        return mounts
    }
}
