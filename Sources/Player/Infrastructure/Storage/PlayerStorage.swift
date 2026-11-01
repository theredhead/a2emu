import Foundation

/// Resolves saved-data identity and seeds only missing originals; it never prompts or accesses the emulator.
struct PlayerStorage {
    let manager: FileManager
    let supportRoot: URL?

    init(manager: FileManager = .default, supportRoot: URL? = nil) {
        self.manager = manager
        self.supportRoot = supportRoot
    }

    func open(resource: URL, identifier: String, previewDirectory: URL?) throws
        -> (directory: URL, manifest: PlayerManifest)
    {
        let base =
            try supportRoot
            ?? manager.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let current = base.appendingPathComponent(identifier, isDirectory: true)
        let legacyIdentifier = identifier.replacingOccurrences(
            of: "nl.theredhead.applejuicer.juicebox", with: "nl.theredhead.a2emu-player",
            options: .anchored)
        let legacy = base.appendingPathComponent(legacyIdentifier, isDirectory: true)
        // Keep existing absolute disk paths valid when an older player is rebranded.
        let saved =
            manager.fileExists(atPath: current.path) || !manager.fileExists(atPath: legacy.path)
            ? current : legacy
        let directory =
            previewDirectory?.appendingPathComponent("Support", isDirectory: true)
            ?? saved
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let manifest = try JSONDecoder().decode(
            PlayerManifest.self, from: Data(contentsOf: resource.appendingPathComponent("Player.json")))
        try manifest.validate()
        for name in manifest.diskFiles {
            let disk = directory.appendingPathComponent(name)
            if !manager.fileExists(atPath: disk.path) {
                try manager.copyItem(at: resource.appendingPathComponent(name), to: disk)
            }
        }
        return (directory, manifest)
    }
}
