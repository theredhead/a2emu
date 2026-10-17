import Cocoa

/// Uses the real emulator configuration parser and native menus; all files stay in a temporary directory.
@main struct PlayerStateTests {
    static func main() throws {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "a2-player-state-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        g_limit_speed = 1
        g_zip_speed_mhz = 8
        precondition(EmulatorCore.speedLimit == 1 && EmulatorCore.acceleratorSpeedMHz == 8)
        EmulatorCore.speedLimit = 2
        EmulatorCore.acceleratorSpeedMHz = 12
        precondition(g_limit_speed == 2 && g_zip_speed_mhz == 12)
        g_limit_speed = 1
        g_zip_speed_mhz = 8
        let delegate = AppDelegate()
        NSApp.delegate = delegate
        delegate.setUpMenus()
        delegate.addSpeedMenu()
        delegate.emulatorStarted = true
        delegate.supportDirectory = directory
        delegate.machine = try PlayerManifest.make(disks: ["test.woz"], slot: 6)
        delegate.addControlsMenu()
        delegate.addDiskMenus()
        let layout = delegate.playerMenu!
        let emulation = layout.submenu(.emulation)!
        func visibleTitles(_ menu: NSMenu) -> [String] {
            menu.items.filter { !$0.isHidden }.map { $0.isSeparatorItem ? "---" : $0.title }
        }
        layout.menuWillOpen(emulation)
        precondition(
            visibleTitles(emulation) == [
                "Pause", "Reset", "---", "Snapshots…",
            ])
        let configuration = layout.submenu(.configuration)!
        layout.menuWillOpen(configuration)
        precondition(visibleTitles(configuration) == ["Speed", "Controls", "---", "Change ROM…"])
        delegate.menuModifierFlags = { .option }
        layout.menuWillOpen(configuration)
        precondition(visibleTitles(configuration) == ["Speed", "Controls", "---", "Change ROM…", "---", "Configuration  F4", "Show Debugger"])
        let advanced = configuration.items[configuration.numberOfItems - 2]
        let debugger = configuration.items.last!
        precondition(debugger.action == #selector(AppDelegate.showDebugger(_:)) && debugger.target === delegate)
        precondition(advanced.action == #selector(MainView.showEmulatorConfiguration(_:)) && advanced.target == nil)
        delegate.menuModifierFlags = { [] }
        layout.menuWillOpen(layout.submenu(.speed)!)
        precondition(!debugger.isHidden)
        precondition(!advanced.isHidden, "Submenus must retain the mode selected when opening the menu")
        layout.menuWillOpen(configuration)
        precondition(advanced.isHidden && debugger.isHidden)
        precondition(visibleTitles(configuration) == ["Speed", "Controls", "---", "Change ROM…"])
        precondition(configuration.items.contains { $0 === layout.item(.speed) })
        precondition(configuration.items.contains { $0 === layout.item(.controls) })
        precondition(layout.item(.pause)!.target === delegate)
        precondition(layout.item(.pause)!.keyEquivalent == "p")
        precondition(layout.item(.pause)!.keyEquivalentModifierMask == .command)
        let edit = layout.root.items.first { $0.title == "Edit" }!.submenu!
        precondition(edit.items.first!.target == nil, "View commands must keep responder-chain routing")
        let appMenu = layout.root.items[0].submenu!
        let quit = appMenu.items.last!
        precondition(quit.target === NSApp && quit.keyEquivalentModifierMask == [.option, .command])
        // Renaming the parent must not break dynamic sections or their action targets.
        layout.item(.emulation)!.title = "Game"
        emulation.title = "Game"
        delegate.addSpeedMenu()
        delegate.addControlsMenu()
        precondition(layout.submenu(.speed)!.numberOfItems == EmulationSpeed.allCases.count)
        precondition(delegate.controlMenuItems.count == 4)
        precondition(delegate.controlMenuItems.allSatisfy { $0.target === delegate })
        delegate.machine = try PlayerManifest.make(disks: ["a.woz", "b.woz"], slot: 6)
        delegate.addDiskMenus()
        layout.menuWillOpen(emulation)
        precondition(!layout.item(.disks)!.isHidden && delegate.diskMenuItems.count == 6)
        precondition(
            delegate.diskMenuItems.enumerated().allSatisfy { index, choice in
                choice.0.tag == index && choice.0.target === delegate
            })
        delegate.addDiskMenus()
        precondition(delegate.diskMenuItems.count == 6 && layout.submenu(.disks)!.numberOfItems == 4)
        delegate.machine = try PlayerManifest.make(disks: ["test.woz"], slot: 6)
        delegate.addDiskMenus()
        layout.item(.emulation)!.title = "Emulation"
        emulation.title = "Emulation"
        layout.menuWillOpen(emulation)
        precondition(!layout.item(.disks)!.isHidden)
        precondition(layout.root.items.contains { $0 === layout.item(.disks) })
        precondition(!emulation.items.contains { $0 === layout.item(.disks) })
        precondition(visibleTitles(layout.submenu(.disks)!) == ["Show Saved Disk"])
        var available = false
        var visible = false
        let conditional = PlayerMenu(
            entries: [
                .menu(
                    "Conditional",
                    [
                        .separator,
                        .command(
                            "Hidden", action: #selector(AppDelegate.resetGame(_:)), visibleWhen: { visible }),
                        .separator, .separator,
                        .command(
                            "Active", action: #selector(AppDelegate.resetGame(_:)), enabledWhen: { available }
                        ),
                        .separator,
                    ])
            ], target: delegate, menuDelegate: delegate)
        let conditionalMenu = conditional.root.items[0].submenu!
        precondition(visibleTitles(conditionalMenu) == ["Active"])
        precondition(!conditionalMenu.items[4].isEnabled)
        available = true
        visible = true
        conditional.menuWillOpen(conditionalMenu)
        precondition(visibleTitles(conditionalMenu) == ["Hidden", "---", "Active"])
        precondition(conditionalMenu.items[4].isEnabled)
        print(
            "PASS declarative layout, live predicates, separators, routing, renamed menus, and repeated dynamic population"
        )

        let config = directory.appendingPathComponent("config.kegs")
        for speed in EmulationSpeed.allCases {
            let manifest = try PlayerManifest.make(disks: ["test.woz"], slot: 6, initialSpeed: speed)
            try "g_limit_speed = \(manifest.initialSpeed!.rawValue)\ng_zip_speed_mhz = 8\n".write(
                to: config, atomically: true, encoding: .utf8)
            config.path.withCString { config_set_config_kegs_name($0) }
            config_init()
            precondition(g_limit_speed == speed.rawValue && g_zip_speed_mhz == 8)
            delegate.updateSpeedChecks()
            precondition(
                delegate.speedMenuItems.filter { $0.state == .on }.map { $0.tag } == [speed.rawValue])
        }
        let menu = layout.submenu(.emulation)!
        let speedMenu = layout.submenu(.speed)!
        let presetCount = speedMenu.numberOfItems
        for (index, mhz) in [16, 32, 64].enumerated() {
            g_limit_speed = 3
            g_zip_speed_mhz = Int32(mhz)
            delegate.updateSpeedChecks()
            precondition(delegate.speedMenuItems.allSatisfy { $0.state == .off })
            let custom = speedMenu.items.first { $0.title == "\(mhz) MHz" }!
            precondition(custom.state == .on && custom.isEnabled && custom.action != nil)
            precondition(speedMenu.numberOfItems == presetCount + index + 1)
            delegate.updateSpeedChecks()
            precondition(
                speedMenu.numberOfItems == presetCount + index + 1,
                "Refreshing must not duplicate custom items")
            g_zip_speed_mhz = 8
            delegate.changeCustomSpeed(custom)
            precondition(g_limit_speed == 3 && g_zip_speed_mhz == mhz)
        }
        g_limit_speed = 7
        delegate.updateSpeedChecks()
        precondition(speedMenu.items.contains { $0.title == "Custom speed (mode 7)" && $0.state == .on })
        precondition(delegate.speedMenuItems.allSatisfy { $0.state == .off })
        g_limit_speed = 2
        delegate.updateSpeedChecks()
        precondition(speedMenu.numberOfItems == presetCount + 3)
        precondition(speedMenu.items.filter { $0.state == .on }.count == 1)
        let sixteen = speedMenu.items.first { $0.title == "16 MHz" }!
        delegate.changeCustomSpeed(sixteen)
        precondition(g_zip_speed_mhz == 16 && sixteen.state == .on)
        g_limit_speed = 2
        delegate.updateSpeedChecks()
        precondition(delegate.speedMenuItems.filter { $0.state == .on }.map { $0.tag } == [2])
        print(
            "PASS live speed indication, dynamic custom items, selection, deduplication, and session retention"
        )

        let template = root.appendingPathComponent("build/Apple II Player.app")
        let disk = directory.appendingPathComponent("fixture.woz")
        try Data([0, 1, 2, 3]).write(to: disk)
        var revisions: [String] = []
        for (index, speed) in [EmulationSpeed.oneMHz, .twoPointEightMHz].enumerated() {
            let destination = directory.appendingPathComponent("Export-\(index).app")
            try PlayerExporter.export(
                disks: [disk], slot: 6, template: template, destination: destination, initialSpeed: speed)
            let manifest = try PlayerExporter.read(app: destination)
            precondition(manifest.initialSpeed == speed)
            precondition(manifest.configurationRevision != nil)
            revisions.append(manifest.configurationRevision!)
        }
        precondition(
            revisions[0] != revisions[1],
            "A fresh export must reapply startup defaults even for the same game")
        print("PASS fresh exports carry distinct startup-default revisions")

        let view = MainView(frame: NSRect(x: 0, y: 0, width: 4, height: 3))
        let screenshots = directory.appendingPathComponent("Screenshots")
        do {
            _ = try view.saveScreenshot(in: screenshots)
            preconditionFailure("An unavailable frame must fail")
        } catch {}
        view.bitmapContext = CGContext(
            data: nil, width: 4, height: 3, bitsPerComponent: 8, bytesPerRow: 16,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        view.bitmapContext.setFillColor(NSColor.red.cgColor)
        view.bitmapContext.fill(CGRect(x: 0, y: 0, width: 4, height: 3))
        let first = try view.saveScreenshot(in: screenshots)
        let second = try view.saveScreenshot(in: screenshots)
        precondition(first != second)
        let captured = NSBitmapImageRep(data: try Data(contentsOf: first))!
        precondition(captured.pixelsWide == 4 && captured.pixelsHigh == 3)
        precondition(captured.colorAt(x: 0, y: 0)!.redComponent > 0.99)
        let viewMenu = NSApp.mainMenu!.items.first { $0.title == "View" }!.submenu!
        let screenshot = viewMenu.items.first { $0.title == "Save Screenshot" }!
        precondition(screenshot.keyEquivalent == String(UnicodeScalar(NSF3FunctionKey)!))
        precondition(screenshot.keyEquivalentModifierMask.isEmpty)
        print("PASS native-resolution PNG capture, unique filenames, missing-frame failure, and bare F3 menu")

        let snapshotsItem = layout.item(.snapshots)!
        let f2Character = String(UnicodeScalar(NSF2FunctionKey)!)
        precondition(snapshotsItem.keyEquivalent == f2Character && snapshotsItem.keyEquivalentModifierMask.isEmpty)
        let f2 = NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [.function], timestamp: 0,
            windowNumber: 0, context: nil, characters: f2Character, charactersIgnoringModifiers: f2Character,
            isARepeat: false, keyCode: 120)!
        precondition(!view.performKeyEquivalent(with: f2))
        precondition(NSApp.mainMenu!.performKeyEquivalent(with: f2))
        let browser = delegate.snapshotBrowser!
        precondition(browser.window!.isVisible && delegate.emulationPaused)
        precondition(!layout.item(.pause)!.isEnabled)
        delegate.togglePause(nil)
        precondition(delegate.emulationPaused, "Resume must not bypass the browser's pause")
        delegate.showSnapshots(nil)
        precondition(delegate.snapshotBrowser === browser && delegate.emulationPaused)
        browser.window!.performClose(nil)
        precondition(!delegate.emulationPaused && layout.item(.pause)!.isEnabled)
        view.keyDown(with: f2)
        view.keyUp(with: f2)
        precondition(delegate.emulationPaused && browser.window!.isVisible, "F2 must work without entering the core")
        browser.window!.close()
        precondition(!delegate.emulationPaused)
        delegate.setEmulationPaused(true)
        delegate.showSnapshots(nil)
        browser.window!.close()
        precondition(delegate.emulationPaused, "An existing manual pause must survive browsing")
        delegate.setEmulationPaused(false)
        delegate.showSnapshots(nil)
        delegate.setEmulationPaused(true, reason: "Controller disconnected")
        browser.window!.close()
        precondition(delegate.emulationPaused, "A new disconnect or failure pause must survive closing the browser")
        delegate.setEmulationPaused(false)
        print("PASS bare F2 menu and key routing, browser reuse, temporary pause and independent pause preservation")
        delegate.configureControls(nil)
        let controls = NSApp.windows.first { $0.title == "Configure Controls" }!
        precondition(delegate.emulationPaused && controls.isVisible)
        delegate.setSnapshotBrowserOpen(true)
        controls.performClose(nil)
        precondition(delegate.emulationPaused, "Closing controls must preserve the snapshot pause")
        delegate.setSnapshotBrowserOpen(false)
        precondition(!delegate.emulationPaused)
        delegate.setEmulationPaused(true)
        delegate.configureControls(nil)
        controls.performClose(nil)
        precondition(delegate.emulationPaused, "Closing controls must preserve manual pause")
        delegate.setEmulationPaused(false)
        delegate.setDialogOpen(true, reason: "ROM Setup")
        delegate.setDialogOpen(true, reason: "Credits")
        delegate.setDialogOpen(false, reason: "ROM Setup")
        precondition(delegate.emulationPaused)
        delegate.setEmulationPaused(true, reason: "Controller disconnected")
        delegate.setDialogOpen(false, reason: "Credits")
        precondition(delegate.emulationPaused)
        delegate.setEmulationPaused(false)
        print("PASS controller dialog close, overlapping dialogs and independent pause preservation")


        delegate.setEmulationPaused(true, reason: "Controller disconnected")
        precondition(delegate.emulationPaused)
        precondition(menu.items.contains { $0.title == "Resume" })
        let frames = g_vbl_count
        delegate.runEmulationLoop()
        RunLoop.current.run(until: Date().addingTimeInterval(0.12))
        precondition(g_vbl_count == frames, "Paused ticks must not advance the emulator")
        delegate.togglePause(nil)
        precondition(!delegate.emulationPaused && menu.items.contains { $0.title == "Pause" })
        precondition(abs(get_dtime() - g_dtime_last_vbl) < 0.1)
        precondition(abs(get_dtime() - g_dtime_expected) < 0.1)
        print("PASS Pause/Resume menu, frozen frame counter, and resume timing reset")
    }
}
