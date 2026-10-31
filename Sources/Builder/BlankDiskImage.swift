import Foundation

private let blankDiskIntl = BlankDiskIntl()

/// Filesystems supported by the built-in empty-volume formatter.
enum BlankDiskFormat: Int, CaseIterable {
    case proDOS, dos33, unformatted

    var label: String {
        switch self {
        case .proDOS: return "ProDOS"
        case .dos33: return blankDiskIntl.dos33DataDisk
        case .unformatted: return blankDiskIntl.unformatted
        }
    }
}

/// Writable media with optional filesystem initialization; no operating system is installed.
enum BlankDiskImage: Int, CaseIterable {
    case floppy525, floppy35, hardDisk5, hardDisk10, hardDisk20, hardDisk32

    var label: String {
        switch self {
        case .floppy525: return blankDiskIntl.floppy525
        case .floppy35: return blankDiskIntl.floppy35
        case .hardDisk5: return blankDiskIntl.smartportHardDisk5Mb
        case .hardDisk10: return blankDiskIntl.smartportHardDisk10Mb
        case .hardDisk20: return blankDiskIntl.smartportHardDisk20Mb
        case .hardDisk32: return blankDiskIntl.smartportHardDisk32Mb
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

    func supports(_ format: BlankDiskFormat) -> Bool {
        return format != .dos33 || self == .floppy525
    }

    func fileExtension(for format: BlankDiskFormat) -> String {
        return format == .dos33 ? "do" : fileExtension
    }

    /// Writes an empty volume atomically; 3.5-inch images include an unlocked 2IMG header.
    /// DOS 3.3 requires 140 KB media and uses DOS sector order (.do); other images use block order.
    /// Throws for incompatible formats or write errors without leaving a partial image.
    func write(to url: URL, format: BlankDiskFormat = .proDOS) throws {
        guard supports(format) else {
            throw NSError(
                domain: "BlankDiskImage", code: 1,
                userInfo: [NSLocalizedDescriptionKey: blankDiskIntl.incompatibleFormat])
        }

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
        switch format {
        case .proDOS:
            initializeProDOS(&data, offset: headerSize, name: url.deletingPathExtension().lastPathComponent)
        case .dos33:
            initializeDOS33(&data)
        case .unformatted:
            break
        }
        try data.write(to: url, options: .atomic)
    }

    private func initializeProDOS(_ data: inout Data, offset: Int, name: String) {
        data.replaceSubrange(offset..<(offset + 512), with: ProDOSBootLoader.block)
        let blocks = byteCount / 512
        let bitmapBlocks = (blocks + 4095) / 4096
        let firstFreeBlock = 6 + bitmapBlocks
        var volumeName = ""
        for character in name.uppercased().utf8 {
            if (65...90).contains(character) || (48...57).contains(character) || character == 46 {
                volumeName.append(Character(UnicodeScalar(character)))
            } else {
                volumeName.append(".")
            }
            if volumeName.count == 15 { break }
        }
        if let first = volumeName.utf8.first, !(65...90).contains(first) {
            volumeName = "D" + String(volumeName.prefix(14))
        }
        if volumeName.isEmpty { volumeName = "UNTITLED" }
        for block in 2...5 {
            let start = offset + block * 512
            let previous = block == 2 ? 0 : block - 1
            let next = block == 5 ? 0 : block + 1
            data[start] = UInt8(previous)
            data[start + 2] = UInt8(next)
        }

        let root = offset + 2 * 512
        data[root + 4] = 0xf0 | UInt8(volumeName.utf8.count)
        data.replaceSubrange((root + 5)..<(root + 5 + volumeName.utf8.count), with: volumeName.utf8)
        data[root + 0x22] = 0xc3  // Read, write, rename and destroy access.
        data[root + 0x23] = 0x27
        data[root + 0x24] = 13
        data[root + 0x27] = 6
        data[root + 0x29] = UInt8(blocks & 255)
        data[root + 0x2a] = UInt8(blocks >> 8)
        // A set bit is free; leave metadata and nonexistent trailing blocks allocated.
        for block in firstFreeBlock..<blocks {
            data[offset + 6 * 512 + block / 8] |= UInt8(0x80 >> (block % 8))
        }
    }

    private func initializeDOS33(_ data: inout Data) {
        let vtoc = 17 * 16 * 256
        data[vtoc] = 4
        data[vtoc + 1] = 17
        data[vtoc + 2] = 15
        data[vtoc + 3] = 3
        data[vtoc + 6] = 254
        data[vtoc + 0x27] = 122
        data[vtoc + 0x30] = 17
        data[vtoc + 0x31] = 1
        data[vtoc + 0x34] = 35
        data[vtoc + 0x35] = 16
        data[vtoc + 0x37] = 1  // 256-byte sectors, little endian.
        // Reserve the catalog track and the three conventional DOS system tracks.
        for track in 3..<35 where track != 17 {
            data[vtoc + 0x38 + track * 4] = 0xff
            data[vtoc + 0x39 + track * 4] = 0xff
        }
        for sector in 2...15 {
            let catalog = (17 * 16 + sector) * 256
            data[catalog + 1] = 17
            data[catalog + 2] = UInt8(sector - 1)
        }
    }
}
