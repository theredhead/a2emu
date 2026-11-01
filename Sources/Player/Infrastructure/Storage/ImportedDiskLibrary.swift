import Foundation

private let playerIntl = PlayerIntl()

/// Owns the imported-disk index and atomic copy transaction, including snapshot working-copy rollback.
struct ImportedDiskLibrary {
    let directory: URL
    let workingDirectory: URL
    let manager: FileManager

    init(directory: URL, workingDirectory: URL, manager: FileManager = .default) {
        self.directory = directory
        self.workingDirectory = workingDirectory
        self.manager = manager
    }

    private var importedDisksURL: URL { return directory.appendingPathComponent("Imported-Disks.json") }

    func load(into manifest: PlayerManifest) throws -> PlayerManifest {
        guard FileManager.default.fileExists(atPath: importedDisksURL.path) else { return manifest }

        let names = try JSONDecoder().decode([String].self, from: Data(contentsOf: importedDisksURL))
        guard names.count <= 256, Set(names).count == names.count,
            names.allSatisfy({ PlayerSnapshot.safeName($0) && !manifest.diskFiles.contains($0) })
        else {
            throw PlayerManifest.failure(playerIntl.invalidDiskLibrary)
        }

        var updated = manifest
        updated.diskFiles += names
        if let labels = updated.diskNames { updated.diskNames = labels + names }
        try updated.validate()
        return updated
    }

    func importImages(_ urls: [URL], into manifest: PlayerManifest, rename: (String) -> String?) throws
        -> PlayerManifest?
    {
        let extensions = ["woz", "dsk", "do", "po", "2mg", "2img", "hdv", "nib"]
        guard !urls.isEmpty,
            urls.allSatisfy({
                extensions.contains($0.pathExtension.lowercased())
                    && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            })
        else { throw PlayerManifest.failure(playerIntl.invalidDiskDrop) }

        var imported =
            manager.fileExists(atPath: importedDisksURL.path)
            ? try JSONDecoder().decode([String].self, from: Data(contentsOf: importedDisksURL)) : []
        guard imported.count + urls.count <= 256 else {
            throw PlayerManifest.failure(playerIntl.importLimitError)
        }

        let staging = directory.appendingPathComponent(".importing-" + UUID().uuidString)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }

        var copied: [URL] = []
        var committed = false
        defer { if !committed { for url in copied { try? manager.removeItem(at: url) } } }

        var names: [String] = []
        for source in urls {
            var name = source.lastPathComponent
            while !PlayerSnapshot.safeName(name)
                || (name as NSString).pathExtension.lowercased() != source.pathExtension.lowercased()
                || manifest.diskFiles.contains(name)
                || imported.contains(name)
                || manager.fileExists(atPath: directory.appendingPathComponent(name).path)
                || manager.fileExists(atPath: workingDirectory.appendingPathComponent(name).path)
            {
                let replacement = rename(name)
                guard let replacement = replacement else { return nil }
                name = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
                if (name as NSString).pathExtension.isEmpty {
                    name += "." + source.pathExtension.lowercased()
                }
            }

            let destination = directory.appendingPathComponent(name)
            let staged = staging.appendingPathComponent(UUID().uuidString)
            try manager.copyItem(at: source, to: staged)
            try manager.moveItem(at: staged, to: destination)
            copied.append(destination)
            if workingDirectory != directory {
                let working = workingDirectory.appendingPathComponent(name)
                try manager.copyItem(at: destination, to: staged)
                try manager.moveItem(at: staged, to: working)
                copied.append(working)
            }
            imported.append(name)
            names.append(name)
        }

        var updated = manifest
        updated.diskFiles += names
        if let labels = updated.diskNames { updated.diskNames = labels + names }
        try updated.validate()
        try JSONEncoder().encode(imported).write(to: importedDisksURL, options: .atomic)
        committed = true
        return updated
    }
}
