import CryptoKit
import Foundation

/// A portable snapshot package owns its state, preview, and all game disk images.
struct PlayerSnapshot: Codable {
    let version: Int
    let id: UUID
    let title: String
    let gameName: String
    let createdAt: Date
    let diskFiles: [String]
    let mounts: [DiskMount]
    let hashes: [String: String]

    static let fileExtension = "a2snapshot"
    static let stateName = "Machine.state"
    static let previewName = "Preview.png"

    /// Reads a completed package and verifies every payload before it can affect a running machine.
    static func read(at url: URL) throws -> PlayerSnapshot {
        let manager = FileManager.default
        for directory in [url, url.appendingPathComponent("Disks")] {
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw PlayerManifest.failure(
                    "Snapshots must contain their own disk directory, without symbolic links.")
            }
        }
        let metadataURL = url.appendingPathComponent("Snapshot.json")
        let metadataValues = try metadataURL.resourceValues(forKeys: [
            .isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey,
        ])
        guard metadataValues.isRegularFile == true, metadataValues.isSymbolicLink != true else {
            throw PlayerManifest.failure("The snapshot metadata must be an ordinary file.")
        }
        guard (metadataValues.fileSize ?? 0) < 1_048_576 else {
            throw PlayerManifest.failure("The snapshot metadata is too large.")
        }
        let snapshot = try JSONDecoder().decode(Self.self, from: Data(contentsOf: metadataURL))
        let names = snapshot.diskFiles + [stateName, previewName]
        guard snapshot.version == 1, !snapshot.title.isEmpty, !snapshot.diskFiles.isEmpty,
            snapshot.diskFiles.count <= 256, Set(names).count == names.count,
            snapshot.diskFiles.allSatisfy({ safeName($0) }),
            Set(snapshot.hashes.keys) == Set(names),
            snapshot.mounts.allSatisfy({
                snapshot.diskFiles.indices.contains($0.diskIndex) && DriveAddress.all.contains($0.address)
            }),
            Set(snapshot.mounts.map { $0.address }).count == snapshot.mounts.count,
            Set(snapshot.mounts.map { $0.diskIndex }).count == snapshot.mounts.count
        else {
            throw PlayerManifest.failure("The snapshot metadata is invalid or uses an unsupported format.")
        }
        for name in names {
            let file = payload(name, at: url)
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                manager.fileExists(atPath: file.path), try digest(file) == snapshot.hashes[name]
            else {
                throw PlayerManifest.failure("The snapshot is incomplete or damaged: \(name).")
            }
        }
        return snapshot
    }

    /// Rejects snapshots from another core build before exporting an app that cannot use them.
    static func checkCore(at url: URL, template: URL) throws {
        let state = try FileHandle(forReadingFrom: url.appendingPathComponent(stateName))
        defer { try? state.close() }
        let prefix = try state.read(upToCount: 73) ?? Data()
        let expected = try String(
            contentsOf: template.appendingPathComponent("Contents/Resources/Snapshot-Core-ID.txt"),
            encoding: .utf8
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard prefix.count == 73, String(data: prefix.prefix(8), encoding: .utf8) == "A2STATE1",
            String(data: prefix.dropFirst(8).prefix(64), encoding: .utf8) == expected
        else {
            throw PlayerManifest.failure(
                "This snapshot was saved by a different emulator build. Capture a new one with this player version."
            )
        }
    }

    static func safeName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && (name as NSString).lastPathComponent == name
            && !name.contains(":") && name.rangeOfCharacter(from: .controlCharacters) == nil
    }

    static func payload(_ name: String, at url: URL) -> URL {
        if name == stateName || name == previewName { return url.appendingPathComponent(name) }
        return url.appendingPathComponent("Disks", isDirectory: true).appendingPathComponent(name)
    }

    static func digest(_ file: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hash = SHA256()
        while let bytes = try handle.read(upToCount: 1_048_576), !bytes.isEmpty { hash.update(data: bytes) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// Publishes metadata last; callers stage packages and rename them only after this succeeds.
    static func finish(
        at url: URL, title: String, gameName: String, disks: [String], mounts: [DiskMount]
    ) throws -> PlayerSnapshot {
        var hashes: [String: String] = [:]
        for name in disks + [stateName, previewName] { hashes[name] = try digest(payload(name, at: url)) }
        let snapshot = PlayerSnapshot(
            version: 1, id: UUID(), title: title, gameName: gameName, createdAt: Date(),
            diskFiles: disks, mounts: mounts, hashes: hashes)
        try JSONEncoder().encode(snapshot).write(
            to: url.appendingPathComponent("Snapshot.json"), options: .atomic)
        _ = try read(at: url)
        return snapshot
    }
}
