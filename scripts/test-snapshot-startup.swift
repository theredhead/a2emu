import Cocoa

@main struct SnapshotStartupTests {
    static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let manager = FileManager.default
        let root = URL(fileURLWithPath: manager.currentDirectoryPath)
        let temporary = root.appendingPathComponent("build/RastanRegression")
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        let fixture =
            ProcessInfo.processInfo.environment["A2_SNAPSHOT_TEST_PLAYER"]
            ?? root.appendingPathComponent("TestAssets/Rastan/Rastan.app").path
        let resources = URL(fileURLWithPath: fixture).appendingPathComponent("Contents/Resources")
        let snapshot = resources.appendingPathComponent("Startup.a2snapshot")
        let machine = try JSONDecoder().decode(
            PlayerManifest.self, from: Data(contentsOf: resources.appendingPathComponent("Player.json")))
        for name in machine.diskFiles {
            let destination = temporary.appendingPathComponent(name)
            if !manager.fileExists(atPath: destination.path) {
                try manager.copyItem(at: resources.appendingPathComponent(name), to: destination)
            }
        }
        let memoryKB = ProcessInfo.processInfo.environment["A2_MEMORY_TEST_KB"].flatMap(Int.init)
        let romName =
            ProcessInfo.processInfo.environment["A2_MEMORY_TEST_ROM"] == "1"
            ? "Apple-IIGS-ROM01.bin" : "Apple-IIGS-ROM03.bin"
        let config = temporary.appendingPathComponent("config.kegs")
        try """
        s5d1 = \(temporary.appendingPathComponent(machine.diskFiles[0]).path)
        \(machine.batteryConfiguration)
        g_cfg_rom_path = \(root.appendingPathComponent("TestAssets/ROMs/" + romName).path)
        g_mem_size_exp = \((memoryKB ?? 8192) * 1024)
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
        if let memoryKB = memoryKB {
            let base = romName == "Apple-IIGS-ROM01.bin" ? 128 * 1024 : 1024 * 1024
            precondition(g_mem_size_exp == UInt32(memoryKB * 1024))
            precondition(g_mem_size_total == UInt32(base + memoryKB * 1024))
            print("PASS configured expansion RAM", memoryKB, "KB with", romName)
            a2_snapshot_eject_disks()
            return
        }
        delegate.setEmulationPaused(true)
        let frames = g_vbl_count
        delegate.showDebugger(nil)
        let debugger = delegate.debugWindowInfo.window!
        precondition(debugger.isVisible && !delegate.debugWindowInfo.view!.closed)
        precondition(delegate.emulationPaused && g_vbl_count == frames)
        debugger.performClose(nil)
        precondition(!debugger.isVisible && delegate.debugWindowInfo.view!.closed)
        delegate.showDebugger(nil)
        precondition(delegate.debugWindowInfo.window === debugger && debugger.isVisible)
        debugger.performClose(nil)
        delegate.setEmulationPaused(false)
        delegate.mainWindowInfo.window?.makeKeyAndOrderFront(nil)
        print(
            "PASS advanced debugger opens while paused, closes, and reuses its window without advancing frames"
        )
        try delegate.restoreSnapshot(at: snapshot)
        precondition(delegate.snapshotNeedsVideoRefresh)
        precondition(String(cString: a2_snapshot_disk_path(5, 0)).hasSuffix("RastanB.2mg"))
        delegate.refreshSnapshotDisplayIfNeeded()
        for _ in 0..<30 { precondition(run_16ms() == 0) }
        delegate.mainWindowInfo.update()
        let image = delegate.mainWindowInfo.imagePointer.pointee
        let pixelCount = Int(image.a2_width_full * image.a2_height)
        let coreSamples = stride(from: 0, to: pixelCount, by: 16).filter {
            image.wptr[$0] & 0x00ff_ffff != 0
        }.count
        precondition(coreSamples > 500, "The core framebuffer must be rebuilt, not just the saved preview")
        let before = try delegate.mainWindowInfo.view!.saveScreenshot(in: temporary)
        func litSamples(_ url: URL) throws -> Int {
            let image = NSBitmapImageRep(data: try Data(contentsOf: url))!
            var count = 0
            for y in stride(from: 0, to: image.pixelsHigh, by: 4) {
                for x in stride(from: 0, to: image.pixelsWide, by: 4) {
                    let color = image.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                    if color.redComponent + color.greenComponent + color.blueComponent > 0.2 { count += 1 }
                }
            }
            return count
        }
        let beforeSamples = try litSamples(before)
        precondition(beforeSamples > 1500, "A fresh restore must repaint the complete Rastan screen")
        print("PASS fresh-process full screen redraw and second-disk mount", before.path)
        adb_mainwin_focus(1)
        adb_physical_key_update(delegate.mainWindowInfo.imagePointer, 40, 107, 0)
        for _ in 0..<3 { precondition(run_16ms() == 0) }
        adb_physical_key_update(delegate.mainWindowInfo.imagePointer, 40, 107, 1)
        for _ in 0..<30 { precondition(run_16ms() == 0) }
        delegate.mainWindowInfo.update()
        let after = try delegate.mainWindowInfo.view!.saveScreenshot(in: temporary)
        let changed = try Data(contentsOf: before) != Data(contentsOf: after)
        precondition(changed, "Keyboard input must change the restored game")
        let afterSamples = try litSamples(after)
        precondition(afterSamples > 1500)
        let saved = try delegate.saveSnapshot(title: "Input Choice")
        let compressed = try PlayerSnapshot.read(at: saved)
        precondition(compressed.version == 2 && compressed.compressedPayloads != nil)
        let capturedMemory = try compressed.capturedExpansionMemoryKB(at: saved)
        precondition(capturedMemory == 8192)
        try delegate.restoreSnapshot(at: saved)
        delegate.refreshSnapshotDisplayIfNeeded()
        for _ in 0..<30 { precondition(run_16ms() == 0) }
        delegate.mainWindowInfo.update()
        let compressedFrame = try delegate.mainWindowInfo.view!.saveScreenshot(in: temporary)
        let compressedSamples = try litSamples(compressedFrame)
        precondition(compressedSamples > 1500)
        let legacy = delegate.snapshotsDirectory.appendingPathComponent(
            compressed.id.uuidString + ".a2snapshot")
        try manager.moveItem(at: saved, to: legacy)
        let browser = SnapshotBrowser(player: delegate)
        browser.reload()
        precondition(
            manager.fileExists(atPath: saved.path), "Legacy UUID names should migrate when the library opens")
        print("PASS compressed snapshot restore and legacy Finder filename migration")
        precondition(saved.lastPathComponent.contains("input-choice"))
        precondition(UUID(uuidString: saved.deletingPathExtension().lastPathComponent) == nil)
        print("PASS restored keyboard input, readable snapshot filename and Finder icon", saved.path)
        a2_snapshot_eject_disks()
        for (ram, rom) in [(0, 3), (1024, 3), (0, 1), (256, 1)] {
            let child = Process()
            child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
            var environment = ProcessInfo.processInfo.environment
            environment["A2_MEMORY_TEST_KB"] = String(ram)
            environment["A2_MEMORY_TEST_ROM"] = String(rom)
            child.environment = environment
            child.currentDirectoryURL = root
            try child.run()
            child.waitUntilExit()
            precondition(child.terminationStatus == 0)
        }
    }
}
