import Foundation

/// Owns extracted startup-snapshot media. Failed preparation and workspace release remove private copies.
final class BuilderSnapshotWorkspace {
    let snapshot: PlayerSnapshot
    let expansionMemoryKB: Int
    let directory: URL
    private let manager: FileManager

    var disks: [URL] { return snapshot.diskFiles.map { directory.appendingPathComponent($0) } }

    init(url: URL, manager: FileManager = .default) throws {
        self.manager = manager
        self.snapshot = try PlayerSnapshot.read(at: url)
        self.expansionMemoryKB = try snapshot.capturedExpansionMemoryKB(at: url)
        self.directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        do {
            for name in snapshot.diskFiles {
                try snapshot.extract(name, from: url, to: directory.appendingPathComponent(name))
            }
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }

    deinit { try? manager.removeItem(at: directory) }
}
