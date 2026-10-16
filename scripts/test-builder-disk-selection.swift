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
        print("PASS RAM choices and backward-compatible player manifests")
        print("Builder boot selection, speed defaults, initial mount and manual override passed.")
    }
}
