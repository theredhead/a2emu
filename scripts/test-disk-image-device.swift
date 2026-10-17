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
        try check("blocks.2img", size: 800 * 1024 + 64,
                  header: twoMG(800 * 1024, blockFallback: true), slot: 5)
        try check("nibble.2mg", size: 232960 + 64, header: twoMG(232960, format: 2), slot: 6)
        var woz = Data("WOZ2".utf8) + Data(repeating: 0, count: 8)
        woz += Data("INFO".utf8) + Data([2, 0, 0, 0, 2, 2])
        try check("disk.woz", size: woz.count, header: woz, slot: 5)
        woz[21] = 1
        try check("disk.woz", size: woz.count, header: woz, slot: 6)
        for image in BlankDiskImage.allCases {
            let url = directory.appendingPathComponent("Blank-\(image.rawValue)." + image.fileExtension)
            try image.write(to: url)
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
        print("PASS blank floppy and SmartPort capacities, zero-filled sectors and 2IMG header")
        print("Disk image device detection passed.")
    }
}
