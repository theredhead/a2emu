import Foundation

private let snapshotBrowserIntl = SnapshotBrowserIntl()

struct SnapshotCatalog {
    let entries: [(URL, PlayerSnapshot)]
    let renamed: [URL]
}

/// Owns snapshot catalogue reads, legacy names, imports and trash operations; it never changes the running core.
struct SnapshotLibrary {
    let directory: URL
    let bundledSnapshot: URL?

    func catalog() throws -> SnapshotCatalog {
        var renamed: [URL] = []
        let manager = FileManager.default

        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        var urls = try manager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        if let startup = bundledSnapshot {
            urls.append(startup)
        }

        let snapshots: [(URL, PlayerSnapshot)] = urls.filter {
            $0.pathExtension == PlayerSnapshot.fileExtension
        }.compactMap { url -> (URL, PlayerSnapshot)? in
            guard let bytes = try? Data(contentsOf: url.appendingPathComponent("Snapshot.json")),
                bytes.count < 1_048_576,
                let snapshot = try? JSONDecoder().decode(PlayerSnapshot.self, from: bytes)
            else { return nil }

            var displayURL = url
            if url.deletingLastPathComponent() == directory,
                UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil
            {
                let named = directory.appendingPathComponent(snapshot.fileName)
                if !manager.fileExists(atPath: named.path),
                    (try? manager.moveItem(at: url, to: named)) != nil
                {
                    displayURL = named
                    renamed.append(named)
                }
            }
            return (displayURL, snapshot)
        }.sorted { $0.1.createdAt > $1.1.createdAt }
        return SnapshotCatalog(entries: snapshots, renamed: renamed)
    }

    func importSnapshot(at url: URL, accepts: (PlayerSnapshot) -> Bool) throws -> URL {
        let snapshot = try PlayerSnapshot.read(at: url)
        guard accepts(snapshot) else {
            throw PlayerManifest.failure(snapshotBrowserIntl.thisSnapshotUsesADifferentSet)
        }

        let destination = directory.appendingPathComponent(snapshot.fileName)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw PlayerManifest.failure(snapshotBrowserIntl.thisSnapshotIsAlreadyInYour)
        }
        try FileManager.default.copyItem(at: url, to: destination)
        return destination
    }

    func trash(_ url: URL) throws {
        guard url.deletingLastPathComponent() == directory else { return }
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }
}
