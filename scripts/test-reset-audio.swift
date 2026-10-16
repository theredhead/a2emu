import Cocoa

@main struct ResetAudioTests {
    static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let manager = FileManager.default
        let root = URL(fileURLWithPath: manager.currentDirectoryPath)
        let temporary = manager.temporaryDirectory.appendingPathComponent(
            "a2-reset-audio-" + UUID().uuidString)
        try manager.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: temporary) }
        let disk = temporary.appendingPathComponent("Death Sword.2mg")
        try manager.copyItem(
            at: URL(
                fileURLWithPath: ProcessInfo.processInfo.environment["A2_RESET_TEST_DISK"]
                    ?? root.appendingPathComponent("TestAssets/DeathSword/Death Sword.2mg").path),
            to: disk)
        let machine = try PlayerManifest.make(
            disks: [disk.lastPathComponent], slot: 5, initialSpeed: .twoPointEightMHz)
        let rom = root.appendingPathComponent("TestAssets/ROMs/Apple-IIGS-ROM03.bin")
        let config = temporary.appendingPathComponent("config.kegs")
        try """
        s5d1 = \(disk.path)
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
        g_audio_enable = 0
        delegate.main_init()
        delegate.emulatorStarted = true
        a2_audio_test_enable()
        for pass in 0..<4 {
            var audible: UInt64 = 0
            for _ in 0..<1000 {
                precondition(run_16ms() == 0)
                audible += a2_audio_test_render(800)
            }
            print("AUDIO pass \(pass): \(audible) nonzero rendered samples")
            a2_audio_test_report()
            if pass == 1 {
                precondition(audible < 100_000, "The warm-reset regression should remain reproducible")
            } else {
                precondition(
                    audible > 100_000, "The title music must play on initial boot and after each fresh reset")
            }
            if pass == 0 {
                do_reset()
            } else {
                delegate.resetGame(nil)
                precondition(g_limit_speed == 2, "Reset must preserve the selected speed")
                let mounted = a2_snapshot_disk_path(5, 0)!
                precondition(String(cString: mounted) == disk.path, "Reset must retain the mounted disk")
            }
        }
        print(
            "PASS warm-reset regression reproduced; title music survives repeated menu resets at the selected speed"
        )
        a2_snapshot_eject_disks()
    }
}
