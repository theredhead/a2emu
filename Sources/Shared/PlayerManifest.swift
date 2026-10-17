import Foundation

private let commonIntl = CommonIntl()

private let playerManifestIntl = PlayerManifestIntl()

/// Stored speed identifiers shared with the emulator configuration.
enum EmulationSpeed: Int, Codable, CaseIterable {
    case oneMHz = 1
    case twoPointEightMHz = 2
    case eightMHz = 3
    case unlimited = 0
    var label: String {
        switch self {
        case .oneMHz: return playerManifestIntl.oneMHz
        case .twoPointEightMHz: return playerManifestIntl.twoPointEightMHz
        case .eightMHz: return playerManifestIntl.eightMHz
        case .unlimited: return playerManifestIntl.unlimited
        }
    }
}

/// An emulator slot and zero-based drive number.
struct DriveAddress: Codable, Hashable {
    let slot: Int
    let drive: Int
    static var all: [DriveAddress] {
        [5, 6, 7].flatMap { slot in (0..<(slot == 7 ? 16 : 2)).map { DriveAddress(slot: slot, drive: $0) } }
    }

    var label: String {
        slot == 7
            ? playerManifestIntl.smartportDrive(number: drive + 1)
            : playerManifestIntl.drive(
                kind: slot == 6 ? commonIntl.floppy525Type : commonIntl.floppy35Type, number: drive + 1)
    }
}

struct DiskMount: Codable {
    let diskIndex: Int
    let address: DriveAddress
}

/// Bundled startup defaults; optional fields support players exported by earlier versions.
struct PlayerManifest: Codable {
    var configurationRevision: String? = nil
    var startupSnapshot: Bool? = nil
    var expansionMemoryKB: Int? = nil

    static let expansionMemoryChoices = [
        0, 256, 512, 1024, 2048, 3072, 4096, 6144, 8192, 10240, 12288, 14336,
    ]
    let startInFullScreen: Bool?
    let initialSpeed: EmulationSpeed?
    let availableDrives: [DriveAddress]?
    var diskNames: [String]?
    let initialMounts: [DiskMount]?
    let version: Int
    var diskFiles: [String]
    let bootSlot: Int
    let bram1: [UInt8]
    let bram3: [UInt8]

    /// Builds startup defaults, selecting the sole available drive’s slot when applicable.
    /// Throws for an unsupported startup slot or an empty disk list; call `validate()` for full validation.
    static func make(
        disks: [String], slot: Int, mounts: [DiskMount]? = nil, diskNames: [String]? = nil,
        availableDrives: [DriveAddress]? = nil, initialSpeed: EmulationSpeed = .oneMHz,
        startInFullScreen: Bool = false, expansionMemoryKB: Int = 8192
    ) throws -> PlayerManifest {
        let slot = availableDrives?.count == 1 ? availableDrives![0].slot : slot
        guard [5, 6, 7].contains(slot), !disks.isEmpty else {
            throw failure(playerManifestIntl.chooseSlot56Or7)
        }
        return PlayerManifest(
            expansionMemoryKB: expansionMemoryKB, startInFullScreen: startInFullScreen,
            initialSpeed: initialSpeed,
            availableDrives: availableDrives, diskNames: diskNames,
            initialMounts: mounts
                ?? Array(disks.indices.prefix(slot == 7 ? 16 : 2)).map {
                    DiskMount(diskIndex: $0, address: DriveAddress(slot: slot, drive: $0))
                }, version: 1, diskFiles: disks, bootSlot: slot, bram1: batteryRAM(slot: slot, rom3: false),
            bram3: batteryRAM(slot: slot, rom3: true))
    }

    static var displayName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? playerManifestIntl.appleIiPlayer
    }

    /// Trims the display name and throws if it is empty or contains unsafe filename characters.
    static func checkedName(_ name: String) throws -> String {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.rangeOfCharacter(from: .controlCharacters) == nil, !value.contains("/"),
            !value.contains(":")
        else {
            throw failure(playerManifestIntl.enterAnAppNameWithoutSlashes)
        }
        return value
    }

    static func failure(_ message: String) -> NSError {
        NSError(domain: "AppleIIPlayer", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    /// Produces a 256-byte battery RAM bank with startup-slot settings and a checksum.
    static func batteryRAM(slot: Int, rom3: Bool) -> [UInt8] {
        // Factory settings observed from ROM 03's normal initialization.
        let header =
            "00 00 00 01 00 00 0d 06 02 01 01 00 01 00 00 00 00 00 07 06 02 01 01 00 00 00 0f 06 06 00 05 06 01 00 00 00 00 00 00 01 00 00 00 00 05 02 02 00 00 00 2d 2d 00 00 00 00 00 00 02 02 02 06 08 00 01 02 03 04 05 06 07 0a 00 01 02 03 04 05 06 07 08 09 0a 0b 0c 0d 0e 0f 00 00"
        var bytes = header.split(separator: " ").map { UInt8($0, radix: 16)! }
        bytes += Array(repeating: 0xff, count: 256 - bytes.count)
        bytes[0x28] = UInt8(slot)
        if slot == 7 {
            bytes[0x27] = 1
        }
        if !rom3 {
            bytes[0x32] = 0
            bytes[0x33] = 0
        }

        var checksum: UInt16 = 0
        for offset in stride(from: 250, through: 0, by: -1) {
            checksum = (checksum << 1) | (checksum >> 15)
            checksum = checksum &+ UInt16(bytes[offset]) &+ (UInt16(bytes[offset + 1]) << 8)
        }

        let complement = checksum ^ 0xaaaa
        bytes[252] = UInt8(truncatingIfNeeded: checksum)
        bytes[253] = UInt8(truncatingIfNeeded: checksum >> 8)
        bytes[254] = UInt8(truncatingIfNeeded: complement)
        bytes[255] = UInt8(truncatingIfNeeded: complement >> 8)
        return bytes
    }

    /// Throws if the manifest has unsupported settings, unsafe disk names, or inconsistent mounts.
    func validate() throws {
        if let memory = expansionMemoryKB, !Self.expansionMemoryChoices.contains(memory) {
            throw Self.failure(playerManifestIntl.chooseASupportedExpansionRamSize)
        }
        guard version == 1, [5, 6, 7].contains(bootSlot), !diskFiles.isEmpty, bram1.count == 256,
            bram3.count == 256,
            diskFiles.allSatisfy({
                !$0.isEmpty && ($0 as NSString).lastPathComponent == $0 && !$0.contains("\n")
                    && !$0.contains("\r")
            }),
            bram1[0x28] == bootSlot, bram3[0x28] == bootSlot
        else {
            throw Self.failure(playerManifestIntl.thePlayerMachineConfigurationIsInvalid)
        }
        if let names = diskNames {
            guard names.count == diskFiles.count,
                names.allSatisfy({
                    !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && $0.rangeOfCharacter(from: .controlCharacters) == nil
                })
            else {
                throw Self.failure(playerManifestIntl.giveEachDiskANameWithout)
            }
        }
        guard !drives.isEmpty, Set(drives).count == drives.count,
            drives.allSatisfy({ DriveAddress.all.contains($0) }),
            mounts.allSatisfy({ drives.contains($0.address) })
        else {
            throw Self.failure(playerManifestIntl.initialDisksMustUseAnAvailable)
        }
        guard
            mounts.allSatisfy({
                diskFiles.indices.contains($0.diskIndex) && DriveAddress.all.contains($0.address)
            }),
            Set(mounts.map { $0.address }).count == mounts.count,
            Set(mounts.map { $0.diskIndex }).count == mounts.count,
            mounts.contains(where: { $0.address == DriveAddress(slot: bootSlot, drive: 0) })
        else {
            throw Self.failure(
                playerManifestIntl.mountABootDiskInDrive
            )
        }
    }

    var drives: [DriveAddress] {
        availableDrives
            ?? DriveAddress.all.filter { address in mounts.contains(where: { $0.address == address }) }
    }

    func diskName(at index: Int) -> String {
        diskNames?[index] ?? diskFiles[index]
    }

    var mounts: [DiskMount] {
        initialMounts
            ?? Array(diskFiles.indices.prefix(2)).map {
                DiskMount(diskIndex: $0, address: DriveAddress(slot: bootSlot, drive: $0))
            }
    }

    var batteryConfiguration: String {
        [(1, bram1), (3, bram3)].flatMap { bank, bytes in
            stride(from: 0, to: 256, by: 16).map { offset in
                String(format: "bram%d[%02x] = ", bank, offset)
                    + bytes[offset..<offset + 16].map { String(format: "%02x", $0) }.joined(separator: " ")
            }
        }.joined(separator: "\n")
    }

    static func normalizedName(_ name: String) -> String {
        let text = name.folding(
            options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX")
        ).lowercased()
        let normalized = text.components(
            separatedBy: CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789").inverted
        ).filter { !$0.isEmpty }.joined(separator: "-")
        return normalized.isEmpty ? "disk" : normalized
    }
}
