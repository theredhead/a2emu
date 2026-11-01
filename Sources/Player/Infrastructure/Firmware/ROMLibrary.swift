import CryptoKit
import Foundation

private let commonIntl = CommonIntl()
private let romSetupIntl = ROMSetupIntl()

/// Validates and persists shared firmware and per-player selections without presenting UI.
enum ROMLibrary {
    static let mirror =
        "https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Computers/Apple%20II/Apple%20IIGS/ROM%20Images/"
    static let filename = "Installed.rom"

    static func error(_ message: String) -> NSError {
        NSError(domain: "ROMSetup", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    /// Returns complete ROM 01/03 bytes in emulator bank order, or throws for unrecognized data.
    static func normalized(_ data: Data) throws -> Data {
        guard data.count == 131072 || data.count == 262144 else {
            throw error(
                romSetupIntl.chooseAComplete128KbRom
            )
        }

        let bankCount = data.count / 65536
        let banks = (0..<bankCount).map { data.subdata(in: ($0 * 65536)..<(($0 + 1) * 65536)) }

        func isLastBank(_ b: Data) -> Bool {
            b[0xfffc] == 0x62 && b[0xfffd] == 0xfa && b[0xfded] == 0x6c
        }
        if isLastBank(banks[bankCount - 1]) {
            return data
        }
        // Some chip dumps list banks in reverse order.
        if isLastBank(banks[0]) {
            return banks.reversed().reduce(Data(), +)
        }
        throw error(
            romSetupIntl.thisImageDoesNotContainA
        )
    }

    static let selectionFilename = "Selected-ROM.txt"

    static func sharedDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("nl.theredhead.a2emu.player/ROMs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Returns the recorded shared ROM only if its filename and contents are valid.
    static func selected(in directory: URL) -> URL? {
        guard let shared = try? sharedDirectory(),
            let name = try? String(
                contentsOf: directory.appendingPathComponent(selectionFilename), encoding: .utf8),
            name == URL(fileURLWithPath: name).lastPathComponent, name.hasSuffix(".rom")
        else {
            return nil
        }

        let url = shared.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url), (try? normalized(data)) != nil else {
            return nil
        }
        return url
    }

    static func select(_ url: URL, directory: URL) throws -> URL {
        try url.lastPathComponent.write(
            to: directory.appendingPathComponent(selectionFilename), atomically: true, encoding: .utf8)
        return url
    }

    /// Resolves this player’s selection, adopts legacy firmware, or selects a valid shared ROM.
    /// Returns nil if none is available; throws if library access or selection persistence fails.
    static func existing(directory: URL) throws -> URL? {
        if let selected = selected(in: directory) {
            return selected
        }
        // Preserve an existing player's ROM choice when adopting the shared library.
        let legacy = directory.appendingPathComponent(filename)
        if let data = try? Data(contentsOf: legacy), (try? normalized(data)) != nil {
            return try install(data, directory: directory)
        }

        let shared = try sharedDirectory()
        if let installed = selected(in: shared) {
            return try select(installed, directory: directory)
        }

        let candidates = try FileManager.default.contentsOfDirectory(
            at: shared, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "rom" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        let valid = candidates.filter { url in
            guard let data = try? Data(contentsOf: url) else {
                return false
            }
            return (try? normalized(data)) != nil
        }
        if let installed = valid.first(where: { (try? Data(contentsOf: $0).count) == 262144 }) ?? valid.first
        {
            return try select(installed, directory: directory)
        }
        return nil
    }

    /// Normalizes and stores firmware by content hash, then selects it globally and for this player.
    static func install(_ data: Data, directory: URL) throws -> URL {
        let bytes = try normalized(data)
        let shared = try sharedDirectory()
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let url = shared.appendingPathComponent(digest + ".rom")
        try bytes.write(to: url, options: .atomic)
        _ = try select(url, directory: shared)
        return try select(url, directory: directory)
    }
}
