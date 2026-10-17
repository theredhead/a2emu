import Foundation

/// The most likely drive for a disk image. Users can override this initial selection in the builder.
enum DiskImageDevice {
    case floppy525
    case floppy35
    case smartPort

    var slot: Int {
        switch self {
        case .floppy525: return 6
        case .floppy35: return 5
        case .smartPort: return 7
        }
    }

    static func detect(_ url: URL) -> DiskImageDevice {
        let extensionName = url.pathExtension.lowercased()
        if extensionName == "hdv" {
            return .smartPort
        }
        if extensionName == "nib" {
            return .floppy525
        }
        let fallback: DiskImageDevice = ["2mg", "2img"].contains(extensionName) ? .floppy35 : .floppy525
        guard let file = try? FileHandle(forReadingFrom: url) else {
            return fallback
        }
        defer { try? file.close() }
        guard let size = try? file.seekToEnd() else {
            return fallback
        }
        try? file.seek(toOffset: 0)
        let header = file.readData(ofLength: 256)

        func word(_ offset: Int) -> UInt64 {
            guard offset + 4 <= header.count else { return 0 }
            return (0..<4).reduce(UInt64(0)) { $0 | (UInt64(header[offset + $1]) << ($1 * 8)) }
        }

        if header.prefix(4) == Data("2IMG".utf8) {
            guard header.count >= 32 else { return fallback }
            if word(12) == 2 {
                return .floppy525
            }
            var dataSize = word(28)
            if dataSize == 0, word(12) == 1 {
                dataSize = word(20) * 512
            }
            // Some older writers stored the 800 KB length with its bytes reversed.
            if dataSize == 0x800c00 {
                dataSize = 800 * 1024
            }
            let offset = word(24)
            guard dataSize > 0, offset >= 32, offset <= size, dataSize <= size - offset else {
                return fallback
            }
            return device(forSize: dataSize, fallback: fallback)
        }
        if header.prefix(4) == Data("WOZ1".utf8) || header.prefix(4) == Data("WOZ2".utf8) {
            var offset: UInt64 = 12
            while offset <= size, size - offset >= 10 {
                guard (try? file.seek(toOffset: offset)) != nil else { break }
                let chunk = file.readData(ofLength: 10)
                guard chunk.count == 10 else { break }
                if chunk.prefix(4) == Data("INFO".utf8) {
                    return chunk[9] == 2 ? .floppy35 : .floppy525
                }
                let length = (0..<4).reduce(UInt64(0)) { $0 | (UInt64(chunk[4 + $1]) << ($1 * 8)) }
                guard length <= size - offset - 8 else { break }
                offset += 8 + length
            }
            return .floppy525
        }
        return device(forSize: size, fallback: fallback)
    }

    private static func device(forSize size: UInt64, fallback: DiskImageDevice) -> DiskImageDevice {
        switch size {
        case 35 * 13 * 256, 140 * 1024, 160 * 1024:
            return .floppy525
        case 400 * 1024, 800 * 1024:
            return .floppy35
        case let bytes where bytes > 800 * 1024:
            return .smartPort
        default:
            return fallback
        }
    }
}

/// Empty writable media; filesystem initialization is left to the emulated computer.
enum BlankDiskImage: Int, CaseIterable {
    case floppy525, floppy35, hardDisk5, hardDisk10, hardDisk20, hardDisk32

    var label: String {
        switch self {
        case .floppy525: return "5.25-inch floppy — 140 KB"
        case .floppy35: return "3.5-inch floppy — 800 KB"
        case .hardDisk5: return "SmartPort hard disk — 5 MB"
        case .hardDisk10: return "SmartPort hard disk — 10 MB"
        case .hardDisk20: return "SmartPort hard disk — 20 MB"
        case .hardDisk32: return "SmartPort hard disk — 32 MB"
        }
    }

    var fileExtension: String {
        switch self {
        case .floppy525: return "po"
        case .floppy35: return "2mg"
        default: return "hdv"
        }
    }

    var byteCount: Int {
        switch self {
        case .floppy525: return 140 * 1024
        case .floppy35: return 800 * 1024
        case .hardDisk5: return 5 * 1024 * 1024
        case .hardDisk10: return 10 * 1024 * 1024
        case .hardDisk20: return 20 * 1024 * 1024
        // A ProDOS volume can address at most 65,535 blocks.
        case .hardDisk32: return 65535 * 512
        }
    }

    /// Writes zero-filled sector data atomically; 3.5-inch images include an unlocked 2IMG header.
    /// Throws without leaving a partial image if the destination cannot be written.
    func write(to url: URL) throws {
        let headerSize = self == .floppy35 ? 64 : 0
        var data = Data(count: headerSize + byteCount)
        if headerSize != 0 {
            data.replaceSubrange(0..<8, with: Data("2IMGA2PB".utf8))
            data[8] = 64
            data[10] = 1
            data[12] = 1  // ProDOS sector order.
            for (offset, value) in [(20, byteCount / 512), (24, headerSize), (28, byteCount)] {
                for byte in 0..<4 { data[offset + byte] = UInt8((value >> (byte * 8)) & 255) }
            }
        }
        try data.write(to: url, options: .atomic)
    }
}
