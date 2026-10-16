import Compression
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
    var expansionMemoryKB: Int? = nil
    var compressedPayloads: [String: ExpandedPayload]? = nil

    struct ExpandedPayload: Codable {
        let size: Int
        let hash: String
    }

    static let maximumCompressedPayloadSize = 64 * 1024 * 1024

    static let fileExtension = "a2snapshot"
    static let stateName = "Machine.state"
    static let previewName = "Preview.png"

    /// Includes the game, checkpoint, capture date and a short collision-resistant identifier.
    var fileName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let game = String(PlayerManifest.normalizedName(gameName).prefix(48))
        let checkpoint = String(PlayerManifest.normalizedName(title).prefix(48))
        return
            "\(game) — \(checkpoint) — \(formatter.string(from: createdAt)) — \(id.uuidString.prefix(8)).\(Self.fileExtension)"
    }

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
        guard [1, 2].contains(snapshot.version), !snapshot.title.isEmpty, !snapshot.diskFiles.isEmpty,
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
        if let compressed = snapshot.compressedPayloads {
            guard Set(compressed.keys).isSubset(of: Set(snapshot.diskFiles + [stateName])),
                compressed.values.allSatisfy({ $0.size > 0 && $0.size <= maximumCompressedPayloadSize })
            else { throw PlayerManifest.failure("The compressed snapshot metadata is invalid.") }
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
        let snapshot = try read(at: url)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stateURL = directory.appendingPathComponent(stateName)
        try snapshot.extract(stateName, from: url, to: stateURL)
        let state = try FileHandle(forReadingFrom: stateURL)
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

    /// Expands bounded LZFSE payloads and verifies their original checksum before use.
    func extract(_ name: String, from package: URL, to destination: URL) throws {
        guard let expanded = compressedPayloads?[name] else {
            try FileManager.default.copyItem(at: Self.payload(name, at: package), to: destination)
            return
        }
        guard expanded.size > 0, expanded.size <= Self.maximumCompressedPayloadSize else {
            throw PlayerManifest.failure("The expanded snapshot payload is too large.")
        }
        let packed = try Data(contentsOf: Self.payload(name, at: package), options: .mappedIfSafe)
        guard !packed.isEmpty, packed.count <= Self.maximumCompressedPayloadSize else {
            throw PlayerManifest.failure("The compressed snapshot payload is invalid.")
        }
        var bytes = Data(count: expanded.size)
        let decoded = bytes.withUnsafeMutableBytes { (output: UnsafeMutableRawBufferPointer) in
            packed.withUnsafeBytes { (input: UnsafeRawBufferPointer) in
                compression_decode_buffer(
                    output.bindMemory(to: UInt8.self).baseAddress!, expanded.size,
                    input.bindMemory(to: UInt8.self).baseAddress!, packed.count, nil, COMPRESSION_LZFSE)
            }
        }
        guard decoded == expanded.size,
            SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == expanded.hash
        else { throw PlayerManifest.failure("The compressed snapshot payload is damaged: \(name).") }
        try bytes.write(to: destination, options: .atomic)
    }

    /// Older snapshots recorded total contiguous RAM in the core header, before explicit metadata existed.
    func capturedExpansionMemoryKB(at package: URL) throws -> Int {
        if let memory = expansionMemoryKB {
            guard PlayerManifest.expansionMemoryChoices.contains(memory) else {
                throw PlayerManifest.failure("This snapshot uses an unsupported RAM configuration.")
            }
            return memory
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = directory.appendingPathComponent(Self.stateName)
        try extract(Self.stateName, from: package, to: state)
        let handle = try FileHandle(forReadingFrom: state)
        defer { try? handle.close() }
        let header = handle.readData(ofLength: 80)
        guard header.count == 80 else { throw PlayerManifest.failure("The snapshot header is incomplete.") }
        let total = (0..<4).reduce(0) { $0 | (Int(header[76 + $1]) << ($1 * 8)) }
        if total == 0xdf0000 { return 14336 }
        let base = total % (1024 * 1024) == 128 * 1024 ? 128 * 1024 : 1024 * 1024
        let memory = max(0, total - base) / 1024
        guard PlayerManifest.expansionMemoryChoices.contains(memory) else {
            throw PlayerManifest.failure("This snapshot uses an unsupported RAM configuration.")
        }
        return memory
    }

    /// Publishes metadata last; callers stage packages and rename them only after this succeeds.
    static func finish(
        at url: URL, title: String, gameName: String, disks: [String], mounts: [DiskMount],
        compress: Bool = false, expansionMemoryKB: Int? = nil
    ) throws -> PlayerSnapshot {
        var compressed: [String: ExpandedPayload] = [:]
        if compress {
            for name in disks + [stateName] {
                let file = payload(name, at: url)
                let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                // Bound peak memory; larger disks remain ordinary payloads in the same package.
                guard size > 0, size <= maximumCompressedPayloadSize else { continue }
                let bytes = try Data(contentsOf: file, options: .mappedIfSafe)
                let packed = try (bytes as NSData).compressed(using: .lzfse) as Data
                if packed.count < bytes.count {
                    compressed[name] = ExpandedPayload(size: size, hash: try digest(file))
                    try packed.write(to: file, options: .atomic)
                }
            }
        }
        var hashes: [String: String] = [:]
        for name in disks + [stateName, previewName] { hashes[name] = try digest(payload(name, at: url)) }
        var snapshot = PlayerSnapshot(
            version: compressed.isEmpty ? 1 : 2, id: UUID(), title: title, gameName: gameName,
            createdAt: Date(),
            diskFiles: disks, mounts: mounts, hashes: hashes)
        snapshot.expansionMemoryKB = expansionMemoryKB
        snapshot.compressedPayloads = compressed.isEmpty ? nil : compressed
        try JSONEncoder().encode(snapshot).write(
            to: url.appendingPathComponent("Snapshot.json"), options: .atomic)
        _ = try read(at: url)
        return snapshot
    }
}
