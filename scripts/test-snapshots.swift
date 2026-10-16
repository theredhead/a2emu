import Cocoa

func require(_ condition: Bool, _ message: String = "Snapshot assertion failed") {
    precondition(condition, message)
}

@main struct SnapshotTests {
    static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let manager = FileManager.default
        let root = URL(fileURLWithPath: manager.currentDirectoryPath)
        let temporary = manager.temporaryDirectory.appendingPathComponent("a2-snapshots-" + UUID().uuidString)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: temporary) }
        let rom = root.appendingPathComponent("TestAssets/ROMs/Apple-IIGS-ROM03.bin")
        let floppy = ProcessInfo.processInfo.environment["A2_SNAPSHOT_FLOPPY"] == "1"
        let diskName = floppy ? "Game.woz" : "Game.hdv"
        let slot = floppy ? 6 : 7
        let disk = temporary.appendingPathComponent(diskName)
        let machine = try PlayerManifest.make(disks: [diskName], slot: slot, initialSpeed: .twoPointEightMHz)
        try manager.copyItem(
            at: root.appendingPathComponent(
                floppy ? "TestAssets/Columns/Columns-IIe.woz" : "TestAssets/ShuffleBoot/Shufflepuck-GSOS.hdv"),
            to: disk)
        let config = temporary.appendingPathComponent("config.kegs")
        try """
        s\(slot)d1 = \(disk.path)
        \(machine.batteryConfiguration)
        g_cfg_rom_path = \(rom.path)
        g_limit_speed = 2
        g_status_enable = 0
        g_config_kegs_auto_update = 0
        g_serial_cfg[0] = -1
        g_serial_cfg[1] = -1
        """.write(to: config, atomically: true, encoding: .utf8)
        config.path.withCString { config_set_config_kegs_name($0) }
        let delegate = AppDelegate()
        NSApp.delegate = delegate
        delegate.supportDirectory = temporary
        delegate.machine = machine
        delegate.setUpMenus()
        delegate.addDiskMenus()
        delegate.addSpeedMenu()
        g_audio_enable = 0
        delegate.initializeEmulator()
        delegate.emulatorStarted = true
        if let package = ProcessInfo.processInfo.environment["A2_SNAPSHOT_CHILD_PACKAGE"] {
            let url = URL(fileURLWithPath: package)
            try delegate.restoreSnapshot(at: url)
            let result = temporary.appendingPathComponent("Cold.state")
            try EmulatorCore.saveSnapshot(at: result)
            require(
                try Data(contentsOf: result)
                    == { () throws -> Data in
                        let metadata = try PlayerSnapshot.read(at: url)
                        let expanded = temporary.appendingPathComponent("Expected.state")
                        try metadata.extract(PlayerSnapshot.stateName, from: url, to: expanded)
                        return try Data(contentsOf: expanded)
                    }(),
                "A fresh process must reconstruct the same machine without saved pointers")
            delegate.refreshSnapshotDisplayIfNeeded()
            for _ in 0..<30 { require(run_16ms() == 0) }
            a2_snapshot_eject_disks()
            print("PASS fresh-process restore and continued execution")
            return
        }
        for _ in 0..<(floppy ? 120 : 900) { require(run_16ms() == 0) }
        delegate.mainWindowInfo.update()
        let saved = try delegate.saveSnapshot(title: "GS/OS checkpoint")
        let metadata = try PlayerSnapshot.read(at: saved)
        require(metadata.diskFiles == [diskName] && metadata.mounts.count == 1)
        require(metadata.version == 2 && metadata.compressedPayloads?[PlayerSnapshot.stateName] != nil)
        let state = temporary.appendingPathComponent("Original.state")
        try metadata.extract(PlayerSnapshot.stateName, from: saved, to: state)
        let original = try Data(contentsOf: state)
        require(
            try Data(contentsOf: saved.appendingPathComponent(PlayerSnapshot.stateName)).count
                < original.count)
        print("PASS compressed machine state and legacy-compatible extraction")
        let frameCount = g_vbl_count
        g_limit_speed = 3
        g_zip_speed_mhz = 16
        for _ in 0..<12 { require(run_16ms() == 0) }
        try delegate.restoreSnapshot(at: saved)
        require(g_vbl_count == frameCount && g_limit_speed == 2)
        let restored = temporary.appendingPathComponent("Restored.state")
        try EmulatorCore.saveSnapshot(at: restored)
        require(
            try Data(contentsOf: restored) == original,
            "Restoration must reproduce the complete machine payload")
        print(
            "PASS complete machine round trip during live boot; speed and frame restored")
        for _ in 0..<120 { require(run_16ms() == 0) }
        try delegate.restoreSnapshot(at: saved)
        require(g_vbl_count == frameCount)
        print("PASS continued execution after restore and repeated return to the saved frame")
        _ = try delegate.saveSnapshot(title: "Second saved moment")
        _ = try delegate.saveSnapshot(title: "Ready to play")
        let browser = SnapshotBrowser(player: delegate)
        browser.window?.appearance = NSAppearance(named: .darkAqua)
        browser.reload()
        browser.showWindow(nil)
        browser.window?.setContentSize(NSSize(width: 850, height: 610))
        delegate.setEmulationPaused(true)
        RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        browser.window?.contentView?.layoutSubtreeIfNeeded()
        browser.window?.displayIfNeeded()
        if let content = browser.window?.contentView,
            let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds)
        {
            content.cacheDisplay(in: content.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(
                to: URL(fileURLWithPath: "/private/tmp/a2-snapshot-grid.png"))
        }
        browser.window?.close()
        delegate.setEmulationPaused(false)
        let working = delegate.currentDiskDirectory.appendingPathComponent(diskName)
        require(working != disk)
        let immutable =
            try metadata.compressedPayloads?[diskName]?.hash
            ?? PlayerSnapshot.digest(PlayerSnapshot.payload(diskName, at: saved))
        let packedHash = try PlayerSnapshot.digest(PlayerSnapshot.payload(diskName, at: saved))
        let handle = try FileHandle(forWritingTo: working)
        try handle.seek(toOffset: 1024)
        try handle.write(contentsOf: Data([0xaa, 0xbb, 0xcc]))
        try handle.close()
        require(try PlayerSnapshot.digest(PlayerSnapshot.payload(diskName, at: saved)) == packedHash)
        require(try PlayerSnapshot.digest(disk) == immutable)
        try delegate.restoreSnapshot(at: saved)
        require(
            try PlayerSnapshot.digest(delegate.currentDiskDirectory.appendingPathComponent(diskName))
                == immutable)
        print("PASS isolated writable disks; repeated restore keeps saved and original disks unchanged")
        var damaged = original
        damaged[damaged.count / 2] ^= 0xff
        let badState = temporary.appendingPathComponent("Bad.state")
        try damaged.write(to: badState)
        require(badState.path.withCString { a2_snapshot_restore($0) } == 0)
        require(g_vbl_count == frameCount)
        try original.prefix(90).write(to: badState)
        require(badState.path.withCString { a2_snapshot_validate($0) } == 0)
        print("PASS damaged and truncated core state rejected before machine mutation")
        let badPackage = temporary.appendingPathComponent("Bad.a2snapshot")
        try manager.copyItem(at: saved, to: badPackage)
        try damaged.write(to: badPackage.appendingPathComponent(PlayerSnapshot.stateName))
        do {
            _ = try PlayerSnapshot.read(at: badPackage)
            preconditionFailure("A modified package must fail validation")
        } catch {}
        var wrongBuild = original
        wrongBuild[8] ^= 0x01
        try wrongBuild.write(to: badState)
        require(badState.path.withCString { a2_snapshot_validate($0) } == 0)
        print("PASS incompatible core build rejected")
        if !floppy {
            let badDisks = temporary.appendingPathComponent("Bad Disks.a2snapshot")
            try manager.createDirectory(
                at: badDisks.appendingPathComponent("Disks"), withIntermediateDirectories: true)
            for name in metadata.diskFiles + [PlayerSnapshot.stateName, PlayerSnapshot.previewName] {
                try metadata.extract(name, from: saved, to: PlayerSnapshot.payload(name, at: badDisks))
            }
            let truncated = try FileHandle(forWritingTo: PlayerSnapshot.payload(diskName, at: badDisks))
            try truncated.truncate(atOffset: 512)
            try truncated.close()
            _ = try PlayerSnapshot.finish(
                at: badDisks, title: "Wrong disk geometry", gameName: "Test",
                disks: [diskName], mounts: metadata.mounts)
            let before = temporary.appendingPathComponent("Before failure.state")
            let after = temporary.appendingPathComponent("After failure.state")
            try EmulatorCore.saveSnapshot(at: before)
            let previousDirectory = delegate.currentDiskDirectory
            do {
                try delegate.restoreSnapshot(at: badDisks)
                preconditionFailure("Wrong disk dimensions must fail restoration")
            } catch {}
            try EmulatorCore.saveSnapshot(at: after)
            require(
                try Data(contentsOf: before) == Data(contentsOf: after),
                "Failed restore must recover every machine field")
            require(delegate.currentDiskDirectory == previousDirectory)
            print("PASS failed disk-layout restore rolls back the previous complete machine and disk mounts")
        }
        let template = root.appendingPathComponent("build/Apple II Player.app")
        let exported = temporary.appendingPathComponent("Snapshot Player.app")
        try PlayerExporter.export(
            disks: [disk], slot: slot, template: template, destination: exported,
            initialSpeed: .twoPointEightMHz, startupSnapshot: saved)
        let manifest = try PlayerExporter.read(app: exported)
        require(manifest.startupSnapshot == true)
        let bundled = exported.appendingPathComponent("Contents/Resources/Startup.a2snapshot")
        _ = try PlayerSnapshot.read(at: bundled)
        let child = Process()
        child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        child.currentDirectoryURL = root
        var environment = ProcessInfo.processInfo.environment
        environment["A2_SNAPSHOT_CHILD_PACKAGE"] = bundled.path
        child.environment = environment
        try child.run()
        child.waitUntilExit()
        require(child.terminationStatus == 0, "Restoring in a fresh process must succeed")
        try manager.removeItem(at: saved)
        _ = try PlayerSnapshot.read(at: bundled)
        print("PASS self-contained exported startup snapshot remains valid after source snapshot removal")
        a2_snapshot_eject_disks()
    }
}
