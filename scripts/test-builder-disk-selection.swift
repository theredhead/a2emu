import Cocoa

@main struct BuilderDiskSelectionTests {
    static func main() {
        _ = NSApplication.shared
        let builder = Builder()
        builder.speed.addItems(withTitles: EmulationSpeed.allCases.map { $0.label })
        builder.slot.addItems(withTitles: ["5.25", "3.5", "SmartPort"])
        for limit in [2, 2, 16] {
            let count = NSPopUpButton(frame: .zero)
            count.addItems(withTitles: (0...limit).map(String.init))
            builder.driveCounts.append(count)
        }
        for (name, slot) in [("game.2mg", 5), ("game.hdv", 7), ("game.nib", 6)] {
            builder.selectDisks([URL(fileURLWithPath: "/nonexistent/" + name)])
            precondition(builder.speed.indexOfSelectedItem == (slot == 6 ? 0 : 1))
            precondition(builder.configuredDrives == [DriveAddress(slot: slot, drive: 0)])
            precondition(builder.mountChoices[0].indexOfSelectedItem == 1)
            precondition([6, 5, 7][builder.slot.indexOfSelectedItem] == slot)
        }
        builder.slot.selectItem(at: 2)
        builder.startupChanged(nil)
        precondition(builder.configuredDrives == [DriveAddress(slot: 7, drive: 0)])
        precondition(builder.speed.indexOfSelectedItem == 1)
        builder.speed.selectItem(at: 0)
        builder.speedChanged(nil)
        builder.selectDisks([URL(fileURLWithPath: "/nonexistent/game.hdv")])
        precondition(builder.speed.indexOfSelectedItem == 0, "Explicit 1 MHz must survive detection")
        builder.speed.selectItem(at: 3)
        builder.speedChanged(nil)
        builder.selectDisks([URL(fileURLWithPath: "/nonexistent/game.2mg")])
        precondition(
            builder.speed.indexOfSelectedItem == 3, "Explicit unlimited speed must survive detection")
        for memory in PlayerManifest.expansionMemoryChoices {
            let manifest = try! PlayerManifest.make(disks: ["Game.2mg"], slot: 5, expansionMemoryKB: memory)
            try! manifest.validate()
            precondition(manifest.expansionMemoryKB == memory)
        }
        var oldJSON =
            try! JSONSerialization.jsonObject(
                with: JSONEncoder().encode(
                    PlayerManifest.make(disks: ["Game.2mg"], slot: 5))) as! [String: Any]
        oldJSON.removeValue(forKey: "expansionMemoryKB")
        let oldManifest = try! JSONDecoder().decode(
            PlayerManifest.self, from: JSONSerialization.data(withJSONObject: oldJSON))
        precondition(oldManifest.expansionMemoryKB == nil)
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let disk = temporary.appendingPathComponent("Drop.2mg")
        try! Data(repeating: 0, count: 819200).write(to: disk)
        builder.acceptDroppedFiles([disk])
        precondition(builder.disks == [disk])
        builder.memory.addItems(withTitles: PlayerManifest.expansionMemoryChoices.map(String.init))
        let package = temporary.appendingPathComponent("Game.a2snapshot")
        try! FileManager.default.createDirectory(
            at: package.appendingPathComponent("Disks"), withIntermediateDirectories: true)
        let names = ["First.2mg", "Second.2mg"]
        let bytes = Data(repeating: 42, count: 819200)
        for name in names { try! bytes.write(to: PlayerSnapshot.payload(name, at: package)) }
        try! Data(repeating: 0, count: 1024).write(to: PlayerSnapshot.payload(PlayerSnapshot.stateName, at: package))
        try! Data([1, 2, 3]).write(to: PlayerSnapshot.payload(PlayerSnapshot.previewName, at: package))
        _ = try! PlayerSnapshot.finish(
            at: package, title: "Ready", gameName: "Snapshot Game", disks: names,
            mounts: [DiskMount(diskIndex: 1, address: DriveAddress(slot: 5, drive: 1))],
            compress: true, expansionMemoryKB: 1024)
        builder.acceptDroppedFiles([package])
        precondition(builder.appName.stringValue == "Snapshot Game")
        precondition(builder.disks.map { $0.lastPathComponent } == names)
        precondition(try! Data(contentsOf: builder.disks[0]) == bytes)
        precondition(builder.configuredDrives == [DriveAddress(slot: 5, drive: 0), DriveAddress(slot: 5, drive: 1)])
        precondition(builder.mountChoices[0].indexOfSelectedItem == 0)
        precondition(builder.mountChoices[1].indexOfSelectedItem == 2)
        precondition(PlayerManifest.expansionMemoryChoices[builder.memory.indexOfSelectedItem] == 1024)
        precondition(!builder.memory.isEnabled && !builder.speed.isEnabled)
        let workingDisk = builder.disks[0]
        let damaged = package.appendingPathComponent("Snapshot.json")
        try! Data().write(to: damaged)
        do {
            try builder.selectSnapshot(package)
            preconditionFailure("Damaged snapshot accepted")
        } catch {
            precondition(builder.disks[0] == workingDisk)
            precondition(FileManager.default.fileExists(atPath: workingDisk.path))
        }
        builder.selectDisks([disk])
        precondition(builder.startupSnapshot == nil && builder.memory.isEnabled && builder.speed.isEnabled)
        precondition(!FileManager.default.fileExists(atPath: workingDisk.path))
        print("PASS disk drops, compressed snapshot setup, exact mounts, failure isolation and working-copy cleanup")
        print("PASS RAM choices and backward-compatible player manifests")
        print("Builder boot selection, speed defaults, initial mount and manual override passed.")
    }
}
