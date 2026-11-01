import Foundation

extension DiskBootability {
    /// Reads bounded sector/block metadata. Custom loaders and encoded media remain unknown.
    static func inspect(_ url: URL) -> DiskBootability {
        guard let image = BlockImage(url) else { return .unknown }
        guard let boot = image.block(0) else { return .unknown }
        if boot.allSatisfy({ $0 == 0 }) { return .notBootable }
        guard boot == ProDOSBootLoader.block else { return .unknown }
        return inspectProDOS(image)
    }

    /// Follows the root directory, including chained blocks, without trusting malformed lengths or links.
    private static func inspectProDOS(_ image: BlockImage) -> DiskBootability {
        guard let root = image.block(2), root[4] >> 4 == 15,
            root[0x23] == 39, root[0x24] == 13,
            root.word(0x29) > 2, root.word(0x29) <= image.blockCount
        else { return .unknown }

        let volumeBlocks = root.word(0x29)
        var visited = Set<Int>()
        var number = 2
        var previous = 0
        while number != 0 {
            guard number < volumeBlocks, visited.count < 64, visited.insert(number).inserted,
                let directory = image.block(number), directory.word(0) == previous
            else { return .unknown }
            for entry in (number == 2 ? 1 : 0)..<13 {
                let offset = 4 + entry * 39
                let storage = directory[offset] >> 4
                let nameLength = Int(directory[offset] & 15)
                guard storage != 0, nameLength == 6,
                    directory.subdata(in: (offset + 1)..<(offset + 7)) == Data("PRODOS".utf8)
                else { continue }
                guard (1...3).contains(storage), directory[offset + 16] == 0xff else { return .unknown }

                let key = directory.word(offset + 17)
                let length = directory.word(offset + 21) | (Int(directory[offset + 23]) << 16)
                guard
                    image.hasStartupFile(
                        key: key, length: length, storage: Int(storage),
                        volumeBlocks: volumeBlocks)
                else { return .unknown }
                return .bootable
            }
            previous = number
            number = directory.word(2)
        }
        return .notBootable
    }
}

/// Owns read-only file access. Accepts raw block images and validated ProDOS-order 2IMG containers.
/// All operations are synchronous on the calling thread; no file handles escape this adapter.
private final class BlockImage {
    private let file: FileHandle
    private let offset: UInt64
    let blockCount: Int

    init?(_ url: URL) {
        let supported = ["po", "hdv", "img", "dsk", "do", "2mg", "2img"]
        guard supported.contains(url.pathExtension.lowercased()),
            let handle = try? FileHandle(forReadingFrom: url)
        else { return nil }

        var accepted = false
        defer { if !accepted { try? handle.close() } }
        guard let size = try? handle.seekToEnd(), (try? handle.seek(toOffset: 0)) != nil,
            let header = Self.read(handle, count: 64), header.count == 64
        else { return nil }

        var start: UInt64 = 0
        var length = size
        if header.starts(with: Data("2IMG".utf8)) {
            guard header.word(8) >= 64, header.dword(12) == 1 else { return nil }
            start = UInt64(header.dword(24))
            length = UInt64(header.dword(28))
            if length == 0 { length = UInt64(header.dword(20)) * 512 }
            guard start >= 64, start <= size, length <= size - start else { return nil }
        } else if ["2mg", "2img"].contains(url.pathExtension.lowercased()) {
            return nil
        }
        guard length >= 1536, length % 512 == 0, length / 512 <= 65536 else { return nil }
        self.file = handle
        self.offset = start
        self.blockCount = Int(length / 512)
        accepted = true
    }

    deinit { try? file.close() }

    private static func read(_ file: FileHandle, count: Int) -> Data? {
        do {
            return try file.read(upToCount: count)
        } catch {
            return nil
        }
    }

    /// Checks every required data/index block of the small boot file; sparse or corrupt files stay unknown.
    func hasStartupFile(key: Int, length: Int, storage: Int, volumeBlocks: Int) -> Bool {
        guard length >= 512, length <= 128 * 1024 else { return false }

        let needed = (length + 511) / 512
        var visited = Set<Int>()

        func read(_ number: Int) -> Data? {
            guard number > 2, number < volumeBlocks, visited.insert(number).inserted else { return nil }
            return block(number)
        }
        guard let keyBlock = read(key) else { return false }

        var index: Data
        switch storage {
        case 1:
            guard needed == 1 else { return false }
            index = Data()
        case 2: index = keyBlock
        case 3:
            guard let child = read(keyBlock.wordPointer(0)) else { return false }
            index = child
        default: return false
        }

        var first = keyBlock
        if storage != 1 {
            for entry in 0..<needed {
                guard let data = read(index.wordPointer(entry)) else { return false }
                if entry == 0 { first = data }
            }
        }
        // Recognized ProDOS startup files enter through a JMP into their loaded $2000 image.
        let entry = first.word(1)
        return first[0] == 0x4c && entry >= 0x2000 && entry < 0x2000 + length
    }

    func block(_ number: Int) -> Data? {
        guard (0..<blockCount).contains(number),
            (try? file.seek(toOffset: offset + UInt64(number) * 512)) != nil,
            let bytes = Self.read(file, count: 512), bytes.count == 512
        else { return nil }
        return bytes
    }
}

extension Data {
    fileprivate func word(_ offset: Int) -> Int {
        return Int(self[offset]) | (Int(self[offset + 1]) << 8)
    }

    fileprivate func wordPointer(_ entry: Int) -> Int {
        return Int(self[entry]) | (Int(self[entry + 256]) << 8)
    }

    fileprivate func dword(_ offset: Int) -> Int {
        return word(offset) | (word(offset + 2) << 16)
    }
}
