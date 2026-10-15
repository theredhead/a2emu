/**********************************************************************/
/*                    GSplus - Apple //gs Emulator                    */
/*                    Based on KEGS by Kent Dickey                    */
/*                    Copyright 2002-2024 Kent Dickey                 */
/*                    Copyright 2025-2026 GSplus Contributors         */
/*                                                                    */
/*      This code is covered by the GNU GPL v3                        */
/*      See the file COPYING.txt or https://www.gnu.org/licenses/     */
/**********************************************************************/

import Cocoa

/// Selects direct context-memory rendering instead of the default bitmap-image path.
let Context_draw = false

/// Coordinates an AppKit window with an image borrowed from the emulator core.
class Window_info {
    var x_win: NSWindow? = nil
    var mac_view: MainView? = nil
    var kimage_ptr: UnsafeMutablePointer<Kimage>! = nil
    var title: String = ""
    var app_delegate: AppDelegate! = nil
    var mac_a2_height: Int = 0

    func set_kimage(
        _ kimage_ptr: UnsafeMutablePointer<Kimage>!,
        title: String, delegate: AppDelegate!
    ) {
        self.kimage_ptr = kimage_ptr
        self.title = title
        self.app_delegate = delegate
    }

    func create_window() {
        let x_xpos = Int(video_get_x_xpos(kimage_ptr))
        let x_ypos = Int(video_get_x_ypos(kimage_ptr))
        let width = Int(video_get_x_width(kimage_ptr))
        let height = Int(video_get_x_height(kimage_ptr))
        let windowRect = NSRect(
            x: x_xpos, y: x_ypos, width: width,
            height: height)
        var window: NSWindow!
        var view: MainView!
        let style: NSWindow.StyleMask = [
            .titled, .closable,
            .resizable, .miniaturizable,
        ]

        window = NSWindow(
            contentRect: windowRect,
            styleMask: style,
            backing: .buffered, defer: false)

        let viewRect = NSRect(
            x: 0, y: 0, width: windowRect.size.width,
            height: windowRect.size.height)
        print("About to init MainView")
        view = MainView(frame: viewRect)
        print("About to set kimage_ptr")
        view.kimage_ptr = kimage_ptr
        print("About to call initialize")
        view.initialize()
        view.closed = false

        window.delegate = app_delegate
        window.contentView = view
        window.makeKeyAndOrderFront(app_delegate)
        window.acceptsMouseMovedEvents = true
        window.title = title
        window.showsToolbarButton = false
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.makeFirstResponder(view)
        window.center()
        window.contentAspectRatio = NSSize(width: width, height: height)

        video_set_active(kimage_ptr, Int32(1))
        video_update_scale(
            kimage_ptr, Int32(width), Int32(height),
            Int32(1))

        x_win = window
        mac_view = view
        mac_a2_height = height
        window.makeKey()
    }

    /// Synchronizes window visibility, size, and pixels with the emulator image.
    func update() {
        let new_height = Int(video_get_a2_height(kimage_ptr))
        let a2_active = video_get_active(kimage_ptr)
        if let view = mac_view {
            if new_height != mac_a2_height {
                mac_resize_window()
            }
            if a2_active == 0 && !view.closed {
                print("a2_active 0 on \(title), calling close")
                x_win!.orderOut(x_win)
                view.closed = true
            } else if a2_active != 0 && view.closed {
                print("Opening closed window \(title)")
                view.closed = false
                x_win!.orderFront(x_win)
                x_win!.makeKey()  // Move to front
            } else if a2_active != 0 {
                view.mac_update_display()
            }
            if (a2_active != 0) && !view.closed {
                if adb_get_copy_requested() != 0 {
                    view.do_copy_text(view)
                }
            }
        } else {
            if a2_active != 0 {
                print("Opening window \(title)")
                create_window()
            }
        }
    }

    func mac_resize_window() {
        let a2_height = Int(video_get_a2_height(kimage_ptr))
        let a2_width = Int(video_get_a2_width(kimage_ptr))
        let ratio = CGFloat(a2_height) / CGFloat(a2_width)

        let contentWidth = x_win!.contentView!.bounds.width
        mac_a2_height = a2_height
        x_win!.contentAspectRatio = NSSize(
            width: a2_width,
            height: a2_height)
        if !x_win!.styleMask.contains(.fullScreen), !app_delegate.changingFullScreen {
            x_win!.setContentSize(NSSize(width: contentWidth, height: contentWidth * ratio))
            app_delegate.snapWindowToIntegerSize()
        }
        // Recreate the bitmap because enabling status lines changes the display height.
        mac_view!.initialize()
        video_update_scale(
            kimage_ptr, Int32(x_win!.frame.width),
            Int32(x_win!.frame.height), 0)
        video_update_xpos_ypos(
            kimage_ptr, Int32(x_win!.frame.origin.x),
            Int32(x_win!.frame.origin.y))
    }

    func update_window_size(width: Int, height: Int) {
        video_update_scale(kimage_ptr, Int32(width), Int32(height), 0)
    }
}

/// Coordinates player startup, saved configuration, menus, and the main-thread emulation loop.
@main
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    static func main() {
        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
    }

    var mainwin_info = Window_info()
    var debugwin_info = Window_info()

    func find_win_info(_ window: NSWindow) -> Window_info {
        if mainwin_info.x_win == window {
            return mainwin_info
        }
        return debugwin_info
    }

    let gamepadInput = GamepadInput()
    let aboutPanel = AppAbout()

    @objc func do_about(_: AnyObject) {
        aboutPanel.show()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("start!")
        set_menu_for_kegs()
        NSApp.activate(ignoringOtherApps: true)  // Bring window to front
        do {
            try prepareGameFiles()
            guard selectedROM != nil else {
                NSApp.terminate(nil)
                return
            }
            set_menu_for_kegs()
            addDiskMenus()
            addSpeedMenu()
            addControlsMenu()
            main_init()
            emulatorStarted = true
            if machine.startInFullScreen == true {
                DispatchQueue.main.async { self.mainwin_info.x_win?.toggleFullScreen(nil) }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Could not start emulator"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        guard emulatorStarted else {
            return
        }
        _ = config_write_config_kegs_file(0)
        // Save mounted drives before ejecting to flush disk writes on shutdown.
        for address in DriveAddress.all {
            iwm_eject_disk_by_num(Int32(address.slot), Int32(address.drive))
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ theApplication: NSApplication
    ) -> Bool {
        // Application will close if main window is closed
        return true
    }

    func windowDidBecomeKey(_ notification: Notification) {
        if let w = notification.object as? NSWindow {
            if w == mainwin_info.x_win {
                adb_mainwin_focus(Int32(1))
            }
        }
        // If window focus is changing, turn off key repeat
        adb_kbd_repeat_off()
    }

    func windowDidResignKey(_ notification: Notification) {
        adb_kbd_repeat_off()
        adb_mainwin_focus(Int32(0))
        CGDisplayShowCursor(CGMainDisplayID())
    }

    func windowDidMove(_ notification: Notification) {
        if let w = notification.object as? NSWindow {
            let win_info = find_win_info(w)
            video_update_xpos_ypos(
                win_info.kimage_ptr,
                Int32(w.frame.origin.x),
                Int32(w.frame.origin.y))
        }
    }

    func windowWillResize(_ window: NSWindow, to frameSize: NSSize)
        -> NSSize
    {
        var result = frameSize
        if window == mainwin_info.x_win, integerResize, !changingFullScreen,
            !window.styleMask.contains(.fullScreen)
        {
            let content = window.contentRect(forFrameRect: NSRect(origin: .zero, size: frameSize)).size
            let base = nativeDisplaySize
            let multiplier = integerMultiplier(for: content, window: window)
            result =
                window.frameRect(
                    forContentRect: NSRect(
                        origin: .zero,
                        size: NSSize(width: base.width * multiplier, height: base.height * multiplier))
                ).size
        }

        let content = window.contentRect(forFrameRect: NSRect(origin: .zero, size: result)).size
        find_win_info(window).update_window_size(width: Int(content.width), height: Int(content.height))
        return result
    }

    var integerResize = false
    var changingFullScreen = false
    var integerResizeItem: NSMenuItem?
    var nativeDisplaySize: NSSize {
        NSSize(
            width: max(1, Int(video_get_a2_width(mainwin_info.kimage_ptr))),
            height: max(1, Int(video_get_a2_height(mainwin_info.kimage_ptr))))
    }

    func windowWillEnterFullScreen(_ notification: Notification) {
        changingFullScreen = true
    }

    func windowDidEnterFullScreen(_ notification: Notification) {
        changingFullScreen = false
    }

    func windowWillExitFullScreen(_ notification: Notification) {
        changingFullScreen = true
    }

    func windowDidExitFullScreen(_ notification: Notification) {
        changingFullScreen = false
        snapWindowToIntegerSize()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        snapWindowToIntegerSize()
    }

    func snapWindowToIntegerSize() {
        guard integerResize, let window = mainwin_info.x_win, !changingFullScreen,
            !window.styleMask.contains(.fullScreen), let content = window.contentView
        else {
            return
        }

        let base = nativeDisplaySize
        let factor = integerMultiplier(for: content.bounds.size, window: window)
        window.setContentSize(NSSize(width: base.width * factor, height: base.height * factor))
    }

    func integerMultiplier(for content: NSSize, window: NSWindow) -> CGFloat {
        let base = nativeDisplaySize
        var factor = max(1, min(content.width / base.width, content.height / base.height).rounded())
        if let screen = window.screen {
            let available = window.contentRect(forFrameRect: screen.visibleFrame).size
            factor = min(
                factor, max(1, floor(min(available.width / base.width, available.height / base.height))))
        }
        return factor
    }

    @objc func toggleIntegerResize(_ sender: NSMenuItem) {
        integerResize.toggle()
        sender.state = integerResize ? .on : .off
        snapWindowToIntegerSize()
    }

    func windowShouldClose(_ window: NSWindow) -> Bool {
        print("windowShouldClose")
        let win_info = find_win_info(window)
        if mainwin_info.x_win == window {
            // User has clicked the close box on the main emulator
            //  window.  Just exit the app
            NSApp.terminate(window)
            return true  // Let main window close
        } else {
            video_set_active(win_info.kimage_ptr, Int32(0))
            win_info.update()
            return false
        }
    }

    func set_menu_for_kegs() {
        let appname = PlayerManifest.displayName
        let menu = NSMenu(title: "MainMenu")
        NSApp.mainMenu = menu

        print("Installing my menu now")

        //   Add "Kegs" menu
        let kegs = NSMenu(title: appname)
        kegs.addItem(
            withTitle: "About \(appname)",
            action: #selector(AppDelegate.do_about(_:)),
            keyEquivalent: "")
        kegs.addItem(NSMenuItem.separator())
        let quit_item = NSMenuItem(
            title: "Quit \(appname)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        quit_item.keyEquivalentModifierMask = [
            .option,
            .command,
        ]
        kegs.addItem(quit_item)
        let kegs_item = NSMenuItem()
        kegs_item.title = appname
        kegs_item.submenu = kegs
        menu.addItem(kegs_item)

        //   Add "Edit" menu
        let edit = NSMenu(title: "Edit")
        edit.addItem(
            withTitle: "Copy Text Screen",
            action: #selector(MainView.do_copy_text(_:)),
            keyEquivalent: "")
        edit.addItem(NSMenuItem.separator())
        edit.addItem(
            withTitle: "Paste",
            action: #selector(MainView.do_paste(_:)),
            keyEquivalent: "")
        let edit_item = NSMenuItem()
        edit_item.title = "Edit"
        edit_item.submenu = edit
        menu.addItem(edit_item)

        //   Add "Config" menu
        let config = NSMenu(title: "Config")
        config.addItem(
            withTitle: "Configuration  F4",
            action: #selector(MainView.do_config(_:)),
            keyEquivalent: "")
        let config_item = NSMenuItem()
        config_item.title = "Config"
        config_item.submenu = config
        menu.addItem(config_item)

        let viewMenu = NSMenu(title: "View")
        let fullscreen = viewMenu.addItem(
            withTitle: "Toggle Full Screen", action: #selector(toggleFullscreen(_:)), keyEquivalent: "f")
        fullscreen.keyEquivalentModifierMask = [.control, .command]
        fullscreen.target = self
        let integerItem = viewMenu.addItem(
            withTitle: "Resize in Integer Multiples", action: #selector(toggleIntegerResize(_:)),
            keyEquivalent: "")
        integerItem.target = self
        integerResizeItem = integerItem
        let viewItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        viewItem.submenu = viewMenu
        menu.addItem(viewItem)
        let gameMenu = NSMenu(title: "Emulation")
        let reset = gameMenu.addItem(withTitle: "Reset", action: #selector(resetGame(_:)), keyEquivalent: "")
        reset.target = self
        let changeROM = gameMenu.addItem(
            withTitle: "Change ROM…", action: #selector(changeROM(_:)), keyEquivalent: "")
        changeROM.target = self
        let files = gameMenu.addItem(
            withTitle: "Show Saved Disk", action: #selector(showSavedDisk(_:)), keyEquivalent: "")
        files.target = self
        let gameItem = NSMenuItem(title: "Emulation", action: nil, keyEquivalent: "")
        gameItem.submenu = gameMenu
        menu.addItem(gameItem)
        show_menu(menu, depth: 0)
    }

    func show_menu(_ menu: NSMenu, depth: Int) {
        if depth >= -10 {
            return  // Menu diagnostics are disabled for normal nonnegative depths.
        }
        print("menu at depth \(depth): \(menu.title)")
        if depth > 5 {  // Prevent infinite recursion
            return
        }
        for menuit in menu.items {
            print("menuit: depth:\(depth) \(menuit.title)")
            print("  keyeq:\(menuit.keyEquivalent)")
            print("  modifiers:\(menuit.keyEquivalentModifierMask)")
            print("  isSeparator:\(menuit.isSeparatorItem)")
            if let sub = menuit.submenu {
                show_menu(sub, depth: depth + 1)
            }
        }
    }

    var mainWindow: NSWindow!
    var mainwin_view: MainView!

    var supportDirectory: URL!
    var selectedROM: URL?
    var emulatorStarted = false
    var settingUpROM = false
    var machine: PlayerManifest!

    /// Seeds missing saved disks and applies revised export defaults while preserving other settings.
    /// Throws on invalid manifests or file errors; ROM cancellation leaves startup incomplete.
    func prepareGameFiles() throws {
        let manager = FileManager.default
        let base = try manager.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        supportDirectory = base.appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
        try manager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        let resource = Bundle.main.resourceURL!
        machine = try JSONDecoder().decode(
            PlayerManifest.self, from: Data(contentsOf: resource.appendingPathComponent("Player.json")))
        try machine.validate()
        for name in machine.diskFiles {
            let disk = supportDirectory.appendingPathComponent(name)
            if !manager.fileExists(atPath: disk.path) {
                try manager.copyItem(at: resource.appendingPathComponent(name), to: disk)
            }
        }
        selectedROM = try ROMSetup.existing(directory: supportDirectory)
        if selectedROM == nil {
            selectedROM = ROMSetup.choose(directory: supportDirectory)
        }
        guard let rom = selectedROM else {
            return
        }

        let config = supportDirectory.appendingPathComponent("config.kegs")
        let settings = """
            \(machine.mounts.map { "s\($0.address.slot)d\($0.address.drive + 1) = \(supportDirectory.appendingPathComponent(machine.diskFiles[$0.diskIndex]).path)" }.joined(separator: "\n"))
            \(machine.batteryConfiguration)
            g_cfg_rom_path = \(rom.path)
            g_limit_speed = \((machine.initialSpeed ?? .oneMHz).rawValue)
            g_zip_speed_mhz = 8
            g_status_enable = 0
            g_config_kegs_auto_update = 0
            """
        if manager.fileExists(atPath: config.path) {
            let previous = try String(contentsOf: config, encoding: .utf8)
            let revisionFile = supportDirectory.appendingPathComponent("Applied-Defaults.txt")
            let applied = try? String(contentsOf: revisionFile, encoding: .utf8)
            let changed = machine.configurationRevision != nil && applied != machine.configurationRevision
            let lines = previous.components(separatedBy: .newlines).filter {
                let line = $0.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("g_cfg_rom_path =") {
                    return false
                }
                guard changed else {
                    return true
                }
                return !line.hasPrefix("bram1[") && !line.hasPrefix("bram3[")
                    && !line.hasPrefix("g_limit_speed =") && !line.hasPrefix("g_zip_speed_mhz =")
                    && line.range(of: "^s[567]d[0-9]+\\s*=", options: .regularExpression) == nil
            }

            let updated = changed ? settings : "g_cfg_rom_path = \(rom.path)"
            try (lines.joined(separator: "\n") + "\n" + updated + "\n").write(
                to: config, atomically: true, encoding: .utf8)
        } else {
            try (settings + "\n").write(to: config, atomically: true, encoding: .utf8)
        }
        if let revision = machine.configurationRevision {
            try revision.write(
                to: supportDirectory.appendingPathComponent("Applied-Defaults.txt"), atomically: true,
                encoding: .utf8)
        }
        config.path.withCString { config_set_config_kegs_name($0) }
    }

    var mountedImages: [DriveAddress: Int] = [:]
    var speedMenuItems: [NSMenuItem] = []

    func addSpeedMenu() {
        guard let emulation = NSApp.mainMenu?.items.first(where: { $0.title == "Emulation" })?.submenu else {
            return
        }

        let menu = NSMenu(title: "Speed")
        menu.delegate = self
        menu.showsStateColumn = true
        let parent = NSMenuItem(title: "Speed", action: nil, keyEquivalent: "")
        parent.submenu = menu
        emulation.addItem(parent)
        for speed in EmulationSpeed.allCases {
            let item = NSMenuItem(title: speed.label, action: #selector(changeSpeed(_:)), keyEquivalent: "")
            item.target = self
            item.tag = speed.rawValue
            menu.addItem(item)
            speedMenuItems.append(item)
        }
    }

    let controllerMappingPanel = ControllerMappingPanel()

    @objc func configureControls(_ sender: Any?) {
        controllerMappingPanel.show(
            mapping: gamepadInput.mapping, controllerName: gamepadInput.controllerName
        ) { [weak self] mapping in
            self?.gamepadInput.mapping = mapping
            g_joystick_type = 4
            _ = config_write_config_kegs_file(0)
            self?.mainwin_info.x_win?.makeKeyAndOrderFront(nil)
            if let view = self?.mainwin_info.mac_view {
                self?.mainwin_info.x_win?.makeFirstResponder(view)
            }
        }
    }

    var controlMenuItems: [NSMenuItem] = []
    var controllerStatusItem: NSMenuItem?

    func addControlsMenu() {
        guard let emulation = NSApp.mainMenu?.items.first(where: { $0.title == "Emulation" })?.submenu else {
            return
        }

        let menu = NSMenu(title: "Controls")
        menu.delegate = self
        let parent = NSMenuItem(title: "Controls", action: nil, keyEquivalent: "")
        parent.submenu = menu
        emulation.addItem(parent)
        for (title, type) in [
            ("Automatic (Controller or Keyboard)", 4), ("Keyboard Joystick (Numeric Keypad)", 0),
            ("Mouse Joystick", 1), ("Game Controller", 2),
        ] {
            let item = NSMenuItem(title: title, action: #selector(changeControls(_:)), keyEquivalent: "")
            item.target = self
            item.tag = type
            menu.addItem(item)
            controlMenuItems.append(item)
        }
        menu.addItem(NSMenuItem.separator())
        let status = NSMenuItem(title: gamepadInput.controllerName, action: nil, keyEquivalent: "")
        menu.addItem(status)
        controllerStatusItem = status
        let configure = menu.addItem(
            withTitle: "Configure Controls…", action: #selector(configureControls(_:)), keyEquivalent: "")
        configure.target = self
    }

    @objc func changeControls(_ sender: NSMenuItem) {
        guard emulatorStarted else {
            return
        }
        g_joystick_type = Int32(sender.tag)
        _ = config_write_config_kegs_file(0)
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateSpeedChecks()
        for item in controlMenuItems {
            item.state = item.tag == Int(g_joystick_type) ? .on : .off
        }
        controllerStatusItem?.title = gamepadInput.controllerName
    }

    func updateSpeedChecks() {
        for item in speedMenuItems {
            item.state = item.tag == Int(g_limit_speed) ? .on : .off
        }
    }

    @objc func changeSpeed(_ sender: NSMenuItem) {
        guard emulatorStarted, let speed = EmulationSpeed(rawValue: sender.tag) else {
            return
        }
        g_limit_speed = Int32(speed.rawValue)
        if speed == .eightMHz {
            g_zip_speed_mhz = 8
            setup_zip_speeds()
        }
        updateSpeedChecks()
        _ = config_write_config_kegs_file(0)
    }

    var diskMenuItems: [(NSMenuItem, DriveAddress, Int?)] = []

    func addDiskMenus() {
        guard machine.drives.count > 1 || machine.diskFiles.count > 1 else {
            return
        }
        guard let emulation = NSApp.mainMenu?.items.first(where: { $0.title == "Emulation" })?.submenu else {
            return
        }

        let disks = NSMenu(title: "Disks")
        let parent = NSMenuItem(title: "Disks", action: nil, keyEquivalent: "")
        parent.submenu = disks
        emulation.addItem(NSMenuItem.separator())
        emulation.addItem(parent)
        if let settings = try? String(
            contentsOf: supportDirectory.appendingPathComponent("config.kegs"), encoding: .utf8)
        {
            for line in settings.components(separatedBy: .newlines) {
                let parts = line.components(separatedBy: "=")
                guard parts.count >= 2 else {
                    continue
                }

                let key = parts[0].trimmingCharacters(in: .whitespaces)
                guard key.hasPrefix("s"), key.count >= 4, let slot = Int(key.dropFirst().prefix(1)),
                    let drive = Int(key.dropFirst(3))
                else {
                    continue
                }

                let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                guard !value.hasPrefix("#"),
                    let index = machine.diskFiles.firstIndex(of: (value as NSString).lastPathComponent)
                else {
                    continue
                }

                let address = DriveAddress(slot: slot, drive: drive - 1)
                if DriveAddress.all.contains(address) {
                    mountedImages[address] = index
                }
            }
        }
        for address in machine.drives {
            let drive = NSMenu(title: address.label)
            let item = NSMenuItem(title: address.label, action: nil, keyEquivalent: "")
            item.submenu = drive
            disks.addItem(item)
            let eject = NSMenuItem(title: "Eject", action: #selector(swapDisk(_:)), keyEquivalent: "")
            eject.target = self
            eject.tag = diskMenuItems.count
            diskMenuItems.append((eject, address, nil))
            drive.addItem(eject)
            drive.addItem(NSMenuItem.separator())
            for index in machine.diskFiles.indices {
                let image = NSMenuItem(
                    title: machine.diskName(at: index), action: #selector(swapDisk(_:)), keyEquivalent: "")
                image.target = self
                image.tag = diskMenuItems.count
                diskMenuItems.append((image, address, index))
                drive.addItem(image)
            }
        }
        updateDiskChecks()
    }

    func updateDiskChecks() {
        for (item, address, index) in diskMenuItems {
            item.state = mountedImages[address] == index ? .on : .off
        }
    }

    @objc func swapDisk(_ sender: NSMenuItem) {
        guard emulatorStarted, diskMenuItems.indices.contains(sender.tag) else {
            return
        }

        let (_, address, index) = diskMenuItems[sender.tag]
        iwm_eject_disk_by_num(Int32(address.slot), Int32(address.drive))
        mountedImages.removeValue(forKey: address)
        if let index = index {
            for (old, mounted) in Array(mountedImages) where mounted == index {
                iwm_eject_disk_by_num(Int32(old.slot), Int32(old.drive))
                mountedImages.removeValue(forKey: old)
            }
            supportDirectory.appendingPathComponent(machine.diskFiles[index]).path.withCString {
                insert_disk(Int32(address.slot), Int32(address.drive), $0, 0, nil, -1, 0)
            }
            mountedImages[address] = index
        }
        updateDiskChecks()
        _ = config_write_config_kegs_file(0)
    }

    @objc func changeROM(_ sender: Any?) {
        guard emulatorStarted else {
            return
        }
        settingUpROM = true
        defer { settingUpROM = false }
        if let rom = ROMSetup.choose(directory: supportDirectory) {
            selectedROM = rom
            rom.path.withCString { cfg_file_update_rom($0) }
        }
    }

    @objc func toggleFullscreen(_ sender: Any?) {
        mainwin_info.x_win?.toggleFullScreen(sender)
    }

    @objc func resetGame(_ sender: Any?) {
        do_reset()
    }

    @objc func showSavedDisk(_ sender: Any?) {
        NSWorkspace.shared.open(supportDirectory)
    }

    func main_init() {
        var kimage_ptr: UnsafeMutablePointer<Kimage>!
        var rect = NSRect.zero

        let argc = CommandLine.argc
        let argv = CommandLine.unsafeArgv
        parse_argv(argc, argv, 3)

        rect.size.width = 2560
        rect.size.height = 1440
        if let screen = NSScreen.main {
            rect = screen.frame
        }
        kegs_init(
            24, Int32(rect.size.width), Int32(rect.size.height),
            Int32(1))
        if Context_draw {
            video_set_blue_mask(UInt32(0x0000ff))
            video_set_green_mask(UInt32(0x00ff00))
            video_set_red_mask(UInt32(0xff0000))
        } else {
            video_set_red_mask(UInt32(0x0000ff))
            video_set_green_mask(UInt32(0x00ff00))
            video_set_blue_mask(UInt32(0xff0000))
        }
        video_set_palette()
        kimage_ptr = video_get_kimage(Int32(0))
        mainwin_info.set_kimage(
            kimage_ptr, title: PlayerManifest.displayName,
            delegate: self)
        kimage_ptr = video_get_kimage(Int32(1))
        debugwin_info.set_kimage(
            kimage_ptr, title: "Debugger",
            delegate: self)

        mainwin_info.create_window()
        NSApp.activate(ignoringOtherApps: true)
        main_run_loop()
    }

    /// Schedules the next main-thread tick and pauses core execution during ROM setup.
    func main_run_loop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1)) {
            self.main_run_loop()
        }
        guard !settingUpROM else {
            return
        }
        gamepadInput.update(
            active: NSApp.isActive && mainwin_info.x_win?.isKeyWindow == true
                && (g_joystick_type == 4 || g_joystick_type == 2)
        ) { key, isUp in
            adb_physical_key_update(self.mainwin_info.kimage_ptr, key, 0, isUp ? 1 : 0)
        }

        let ret = run_16ms()
        if ret != 0 {
            exit(ret)
        }
        mainwin_info.update()
        debugwin_info.update()
    }
}
