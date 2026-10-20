import Foundation

@main struct DiskImageDeviceTests {
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        func check(_ name: String, size: Int, header: Data = Data(), slot: Int) throws {
            let url = directory.appendingPathComponent(name)
            try header.write(to: url)
            let file = try FileHandle(forWritingTo: url)
            try file.truncate(atOffset: UInt64(size))
            try file.close()
            precondition(DiskImageDevice.detect(url).slot == slot, name)
        }
        func twoMG(_ size: Int, format: Int = 1, blockFallback: Bool = false) -> Data {
            var header = Data(repeating: 0, count: 64)
            header.replaceSubrange(0..<4, with: Data("2IMG".utf8))
            func word(_ offset: Int, _ value: Int) {
                for index in 0..<4 { header[offset + index] = UInt8((value >> (index * 8)) & 255) }
            }
            word(12, format)
            word(20, size / 512)
            word(24, 64)
            word(28, blockFallback ? 0 : size)
            return header
        }
        try check("small.hdv", size: 140 * 1024, slot: 7)
        try check("disk.dsk", size: 140 * 1024, slot: 6)
        try check("disk.po", size: 800 * 1024, slot: 5)
        try check("disk.PO", size: 4 * 1024 * 1024, slot: 7)
        try check("unknown.2mg", size: 0, slot: 5)
        for (size, slot) in [(140 * 1024, 6), (800 * 1024, 5), (4 * 1024 * 1024, 7)] {
            try check("wrapped.2mg", size: size + 64 + 120, header: twoMG(size), slot: slot)
        }
        try check(
            "blocks.2img", size: 800 * 1024 + 64,
            header: twoMG(800 * 1024, blockFallback: true), slot: 5)
        try check("nibble.2mg", size: 232960 + 64, header: twoMG(232960, format: 2), slot: 6)
        var woz = Data("WOZ2".utf8) + Data(repeating: 0, count: 8)
        woz += Data("INFO".utf8) + Data([2, 0, 0, 0, 2, 2])
        try check("disk.woz", size: woz.count, header: woz, slot: 5)
        woz[21] = 1
        try check("disk.woz", size: woz.count, header: woz, slot: 6)
        for image in BlankDiskImage.allCases {
            let url = directory.appendingPathComponent("Blank-\(image.rawValue)." + image.fileExtension)
            try image.write(to: url, format: .unformatted)
            let data = try Data(contentsOf: url)
            let header = image == .floppy35 ? 64 : 0
            precondition(data.count == image.byteCount + header)
            precondition(data.dropFirst(header).allSatisfy { $0 == 0 })
            let expectedSlot = image == .floppy525 ? 6 : (image == .floppy35 ? 5 : 7)
            precondition(DiskImageDevice.detect(url).slot == expectedSlot)
            if header != 0 {
                precondition(data.prefix(4) == Data("2IMG".utf8))
                precondition(data[8] == 64 && data[10] == 1 && data[12] == 1)
                let blocks = (0..<4).reduce(0) { $0 | (Int(data[20 + $1]) << (8 * $1)) }
                precondition(blocks * 512 == image.byteCount)
            }
        }
        for image in BlankDiskImage.allCases {
            let url = directory.appendingPathComponent("Formatted-\(image.rawValue)." + image.fileExtension)
            try image.write(to: url)
            let bytes = try Data(contentsOf: url)
            let start = image == .floppy35 ? 64 : 0
            precondition(Array(bytes[start..<(start + 4)]) == [1, 0x38, 0xb0, 3])
            precondition(bytes[(start + 289)..<(start + 295)] == Data("PRODOS".utf8))
            precondition(bytes[(start + 512)..<(start + 1024)].allSatisfy { $0 == 0 })
            let root = start + 1024
            let blocks = image.byteCount / 512
            precondition(Int(bytes[root + 0x29]) + Int(bytes[root + 0x2a]) * 256 == blocks)
            precondition(bytes[root + 4] >> 4 == 15 && bytes[root + 0x23] == 39)
            precondition(bytes[root + 0x24] == 13 && bytes[root + 0x25] == 0 && bytes[root + 0x26] == 0)
            var directories: [Int] = []
            var current = 2
            while current != 0 {
                precondition(!directories.contains(current), "Directory chain must terminate")
                let offset = start + current * 512
                let previous = Int(bytes[offset]) + Int(bytes[offset + 1]) * 256
                precondition(previous == (directories.last ?? 0))
                directories.append(current)
                current = Int(bytes[offset + 2]) + Int(bytes[offset + 3]) * 256
            }
            precondition(directories == [2, 3, 4, 5])
            var free = 0
            let reserved = 6 + (blocks + 4095) / 4096
            for block in 0..<(((blocks + 4095) / 4096) * 4096) {
                let available = bytes[start + 3072 + block / 8] & UInt8(0x80 >> (block % 8)) != 0
                precondition(available == (block >= reserved && block < blocks))
                if available { free += 1 }
            }
            precondition(free == blocks - reserved)
        }
        let dos = directory.appendingPathComponent("DOS33.do")
        try BlankDiskImage.floppy525.write(to: dos, format: .dos33)
        let dosBytes = try Data(contentsOf: dos)
        let vtoc = 17 * 4096
        precondition(dosBytes[vtoc + 1] == 17 && dosBytes[vtoc + 2] == 15)
        precondition(dosBytes[vtoc + 3] == 3 && dosBytes[vtoc + 0x34] == 35)
        var sector = 15
        var catalogSectors = 0
        while sector > 0 {
            let offset = vtoc + sector * 256
            precondition(dosBytes[(offset + 11)..<(offset + 256)].allSatisfy { $0 == 0 })
            sector = dosBytes[offset + 1] == 0 ? 0 : Int(dosBytes[offset + 2])
            catalogSectors += 1
            precondition(catalogSectors <= 15)
        }
        precondition(catalogSectors == 15)
        for track in 0..<35 {
            let free = dosBytes[vtoc + 0x38 + track * 4] == 255
            precondition(free == (track >= 3 && track != 17))
        }
        let protected = directory.appendingPathComponent("Protected.2mg")
        try Data([1, 2, 3]).write(to: protected)
        do {
            try BlankDiskImage.floppy35.write(to: protected, format: .dos33)
            preconditionFailure("Incompatible filesystem accepted")
        } catch {
            precondition(try! Data(contentsOf: protected) == Data([1, 2, 3]))
        }
        precondition(BlankDiskImage.floppy525.fileExtension(for: .dos33) == "do")
        precondition(!BlankDiskImage.hardDisk32.supports(.dos33))
        print(
            "PASS ProDOS directory chains and complete allocation maps at every capacity; DOS catalog and geometry; incompatible-format safety"
        )
        print("PASS blank floppy and SmartPort capacities, zero-filled sectors and 2IMG header")
        print("Disk image device detection passed.")
    }
}
