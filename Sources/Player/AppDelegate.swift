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
let usesDirectContextDrawing = false

/// Coordinates an AppKit window with an image borrowed from the emulator core.
class EmulatorWindow {
    var window: NSWindow? = nil
    var view: MainView? = nil
    var imagePointer: EmulatorCore.Image! = nil
    var title: String = ""
    var delegate: AppDelegate! = nil
    var cachedImageHeight: Int = 0

    func setImage(
        _ imagePointer: EmulatorCore.Image!,
        title: String, delegate: AppDelegate!
    ) {
        self.imagePointer = imagePointer
        self.title = title
        self.delegate = delegate
    }

    func createWindow() {
        let windowX = Int(EmulatorCore.windowX(imagePointer))
        let windowY = Int(EmulatorCore.windowY(imagePointer))
        let width = Int(EmulatorCore.imageWidth(imagePointer))
        let height = Int(EmulatorCore.imageHeight(imagePointer))
        let windowRect = NSRect(
            x: windowX, y: windowY, width: width,
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
        print("About to set imagePointer")
        view.imagePointer = imagePointer
        print("About to call initialize")
        view.initialize()
        view.closed = false

        window.delegate = delegate
        window.contentView = view
        window.makeKeyAndOrderFront(delegate)
        window.acceptsMouseMovedEvents = true
        window.title = title
        window.showsToolbarButton = false
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.makeFirstResponder(view)
        window.center()
        window.contentAspectRatio = NSSize(width: width, height: height)

        EmulatorCore.setImageActivity(imagePointer, active: Int32(1))
        EmulatorCore.updateImageScale(
            imagePointer, width: Int32(width), height: Int32(height),
            force: true)

        self.window = window
        self.view = view
        cachedImageHeight = height
        window.makeKey()
    }

    /// Synchronizes window visibility, size, and pixels with the emulator image.
    func update() {
        let newHeight = Int(EmulatorCore.emulatedImageHeight(imagePointer))
        let imageActive = EmulatorCore.imageActivity(imagePointer)
        if let view = view {
            if newHeight != cachedImageHeight {
                resizeWindow()
            }
            if imageActive == 0 && !view.closed {
                print("imageActive 0 on \(title), calling close")
                window!.orderOut(window)
                view.closed = true
            } else if imageActive != 0 && view.closed {
                print("Opening closed window \(title)")
                view.closed = false
                window!.orderFront(window)
                window!.makeKey()  // Move to front
            } else if imageActive != 0 {
                view.updateDisplay()
            }
            if (imageActive != 0) && !view.closed {
                if EmulatorCore.copyRequested() != 0 {
                    view.copyTextScreen(view)
                }
            }
        } else {
            if imageActive != 0 {
                print("Opening window \(title)")
                createWindow()
            }
        }
    }

    func resizeWindow() {
        let imageHeight = Int(EmulatorCore.emulatedImageHeight(imagePointer))
        let imageWidth = Int(EmulatorCore.emulatedImageWidth(imagePointer))
        let ratio = CGFloat(imageHeight) / CGFloat(imageWidth)

        let contentWidth = window!.contentView!.bounds.width
        cachedImageHeight = imageHeight
        window!.contentAspectRatio = NSSize(
            width: imageWidth,
            height: imageHeight)
        if !window!.styleMask.contains(.fullScreen), !delegate.changingFullScreen {
            window!.setContentSize(NSSize(width: contentWidth, height: contentWidth * ratio))
            delegate.snapWindowToIntegerSize()
        }
        // Recreate the bitmap because enabling status lines changes the display height.
        view!.initialize()
        EmulatorCore.updateImageScale(
            imagePointer, width: Int32(window!.frame.width),
            height: Int32(window!.frame.height), force: false)
        EmulatorCore.updateWindowPosition(
            imagePointer, x: Int32(window!.frame.origin.x),
            y: Int32(window!.frame.origin.y))
    }

    func updateWindowSize(width: Int, height: Int) {
        EmulatorCore.updateImageScale(imagePointer, width: Int32(width), height: Int32(height), force: false)
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

    var mainWindowInfo = EmulatorWindow()
    var debugWindowInfo = EmulatorWindow()

    func windowInfo(for window: NSWindow) -> EmulatorWindow {
        if mainWindowInfo.window == window {
            return mainWindowInfo
        }
        return debugWindowInfo
    }

    let gamepadInput = GamepadInput()
    let aboutPanel = AppAbout()

    @objc func showAbout(_: AnyObject) {
        aboutPanel.show()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("start!")
        gamepadInput.controllerDisconnected = { [weak self] in
            guard let self = self, self.emulatorStarted,
                EmulatorCore.joystickType == 4 || EmulatorCore.joystickType == 2
            else {
                return
            }
            self.setEmulationPaused(true, reason: "Controller disconnected")
        }
        setUpMenus()
        NSApp.activate(ignoringOtherApps: true)  // Bring window to front
        do {
            try prepareGameFiles()
            guard selectedROM != nil else {
                NSApp.terminate(nil)
                return
            }
            setUpMenus()
            addDiskMenus()
            addSpeedMenu()
            addControlsMenu()
            initializeEmulator()
            emulatorStarted = true
            findSnapshotWorkingDisks()
            if machine.startupSnapshot == true {
                let startup = Bundle.main.resourceURL!.appendingPathComponent("Startup.a2snapshot")
                do {
                    try restoreSnapshot(at: startup)
                } catch {
                    setEmulationPaused(true, reason: "Startup snapshot could not be restored")
                    let alert = NSAlert()
                    alert.messageText = "Could not restore startup snapshot"
                    alert.informativeText = error.localizedDescription + " You can resume to boot normally."
                    alert.runModal()
                }
            }
            updatePauseMenu()
            updateSpeedChecks()
            if machine.startInFullScreen == true {
                DispatchQueue.main.async { self.mainWindowInfo.window?.toggleFullScreen(nil) }
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
        EmulatorCore.writeConfiguration()
        // Save mounted drives before ejecting to flush disk writes on shutdown.
        for address in DriveAddress.all {
            EmulatorCore.ejectDisk(slot: Int32(address.slot), drive: Int32(address.drive))
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
            if w == mainWindowInfo.window {
                EmulatorCore.setKeyboardFocus(true)
            }
        }
        // If window focus is changing, turn off key repeat
        EmulatorCore.stopKeyRepeat()
    }

    func windowDidResignKey(_ notification: Notification) {
        EmulatorCore.stopKeyRepeat()
        EmulatorCore.setKeyboardFocus(false)
        CGDisplayShowCursor(CGMainDisplayID())
    }

    func windowDidMove(_ notification: Notification) {
        if let w = notification.object as? NSWindow {
            let info = windowInfo(for: w)
            EmulatorCore.updateWindowPosition(
                info.imagePointer,
                x: Int32(w.frame.origin.x),
                y: Int32(w.frame.origin.y))
        }
    }

    func windowWillResize(_ window: NSWindow, to frameSize: NSSize)
        -> NSSize
    {
        var result = frameSize
        if window == mainWindowInfo.window, integerResize, !changingFullScreen,
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
        windowInfo(for: window).updateWindowSize(width: Int(content.width), height: Int(content.height))
        return result
    }

    var integerResize = false
    var changingFullScreen = false
    var integerResizeItem: NSMenuItem?
    var nativeDisplaySize: NSSize {
        NSSize(
            width: max(1, Int(EmulatorCore.emulatedImageWidth(mainWindowInfo.imagePointer))),
            height: max(1, Int(EmulatorCore.emulatedImageHeight(mainWindowInfo.imagePointer))))
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
        guard integerResize, let window = mainWindowInfo.window, !changingFullScreen,
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
        let info = windowInfo(for: window)
        if mainWindowInfo.window == window {
            // User has clicked the close box on the main emulator
            //  window.  Just exit the app
            NSApp.terminate(window)
            return true  // Let main window close
        } else {
            EmulatorCore.setImageActivity(info.imagePointer, active: Int32(0))
            info.update()
            return false
        }
    }

    var playerMenu: PlayerMenu?
    private(set) var advancedMenus = false
    var menuModifierFlags: () -> NSEvent.ModifierFlags = { NSEvent.modifierFlags }

    func setUpMenus() {
        let entries = PlayerMenuLayout.main(
            appName: PlayerManifest.displayName,
            isRunning: { [weak self] in self?.emulatorStarted == true },
            showAdvanced: { [weak self] in self?.advancedMenus == true })
        let layout = PlayerMenu(entries: entries, target: self, menuDelegate: self)
        playerMenu = layout
        NSApp.mainMenu = layout.root
        pauseMenuItem = layout.item(.pause)
        integerResizeItem = layout.item(.integerResize)
        speedMenuItems = []
        controlMenuItems = []
        diskMenuItems = []
        customSpeedItems = [:]
        unknownSpeedItem = nil
        controllerStatusItem = nil
        updatePauseMenu()
        integerResizeItem?.state = integerResize ? .on : .off
    }

    var mainWindow: NSWindow!
    var mainView: MainView!

    var snapshotDiskDirectory: URL?
    var snapshotNeedsVideoRefresh = false
    var snapshotBrowser: SnapshotBrowser?
    var supportDirectory: URL!
    var selectedROM: URL?
    var emulatorStarted = false
    var settingUpROM = false
    private(set) var emulationPaused = false
    private var pauseMenuItem: NSMenuItem?
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
            g_mem_size_exp = \((machine.expansionMemoryKB ?? 8192) * 1024)
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
                    && !line.hasPrefix("g_mem_size_exp =")
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
        EmulatorCore.setConfigurationPath(config)
    }

    var mountedImages: [DriveAddress: Int] = [:]
    var speedMenuItems: [NSMenuItem] = []
    private var customSpeedItems: [Int32: NSMenuItem] = [:]
    private var unknownSpeedItem: NSMenuItem?

    func addSpeedMenu() {
        guard let layout = playerMenu, let menu = layout.submenu(.speed) else { return }
        layout.replaceContents(of: .speed, with: PlayerMenuLayout.speeds)
        menu.showsStateColumn = true
        speedMenuItems = menu.items
        customSpeedItems = [:]
        unknownSpeedItem = nil
    }

    let controllerMappingPanel = ControllerMappingPanel()

    @objc func configureControls(_ sender: Any?) {
        controllerMappingPanel.show(
            mapping: gamepadInput.mapping,
            controllers: { [weak self] in self?.gamepadInput.availableControllers() ?? [] },
            selectedControllerID: gamepadInput.selectedControllerID,
            preview: { [weak self] mapping, controllerID in
                self?.gamepadInput.previewState(mapping: mapping, controllerID: controllerID)
            },
            completion: { [weak self] mapping, controllerID in
                self?.gamepadInput.selectedControllerID = controllerID
                self?.gamepadInput.mapping = mapping
                EmulatorCore.joystickType = 4
                EmulatorCore.writeConfiguration()
                self?.mainWindowInfo.window?.makeKeyAndOrderFront(nil)
                if let view = self?.mainWindowInfo.view {
                    self?.mainWindowInfo.window?.makeFirstResponder(view)
                }
            })
    }

    var controlMenuItems: [NSMenuItem] = []
    var controllerStatusItem: NSMenuItem?

    func addControlsMenu() {
        guard let layout = playerMenu else { return }
        layout.replaceContents(
            of: .controls,
            with:
                PlayerMenuLayout.controls(controllerName: gamepadInput.controllerName))
        controlMenuItems =
            layout.submenu(.controls)?.items.filter {
                $0.action == #selector(changeControls(_:))
            } ?? []
        controllerStatusItem = layout.item(.controllerStatus)
    }

    @objc func changeControls(_ sender: NSMenuItem) {
        guard emulatorStarted else {
            return
        }
        EmulatorCore.joystickType = Int32(sender.tag)
        EmulatorCore.writeConfiguration()
    }

    func menuWillOpen(_ menu: NSMenu) {
        // Latch the mode when opening a top-level menu; submenus inherit it after Option is released.
        if menu.supermenu === playerMenu?.root {
            advancedMenus = menuModifierFlags().contains(.option)
        }
        updatePauseMenu()
        updateSpeedChecks()
        for item in controlMenuItems {
            item.state = item.tag == Int(EmulatorCore.joystickType) ? .on : .off
        }
        controllerStatusItem?.title = gamepadInput.controllerName
    }

    /// Reflects the core's configured limit and retains discovered Zip speeds for this session.
    func updateSpeedChecks() {
        let knownLimit = EmulationSpeed(rawValue: Int(EmulatorCore.speedLimit))
        let customZip = knownLimit == .eightMHz && EmulatorCore.acceleratorSpeedMHz != 8
        guard let menu = speedMenuItems.first?.menu else { return }
        if customZip, EmulatorCore.acceleratorSpeedMHz > 0,
            customSpeedItems[EmulatorCore.acceleratorSpeedMHz] == nil
        {
            let item = NSMenuItem(
                title: "\(EmulatorCore.acceleratorSpeedMHz) MHz", action: #selector(changeCustomSpeed(_:)),
                keyEquivalent: "")
            item.target = self
            item.representedObject = [
                Int(EmulationSpeed.eightMHz.rawValue), Int(EmulatorCore.acceleratorSpeedMHz),
            ]
            // Keep discovered speeds ordered, immediately before Unlimited.
            let higher = customSpeedItems.keys.filter { $0 > EmulatorCore.acceleratorSpeedMHz }.min()
            let next =
                higher.flatMap { customSpeedItems[$0] }
                ?? speedMenuItems.first { $0.tag == EmulationSpeed.unlimited.rawValue }
            menu.insertItem(item, at: next.map { menu.index(of: $0) } ?? menu.numberOfItems)
            customSpeedItems[EmulatorCore.acceleratorSpeedMHz] = item
        }
        let unknown = knownLimit == nil || (customZip && EmulatorCore.acceleratorSpeedMHz <= 0)
        if unknown {
            if unknownSpeedItem == nil {
                let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.insertItem(item, at: 0)
                unknownSpeedItem = item
            }
            unknownSpeedItem?.title =
                knownLimit == nil
                ? "Custom speed (mode \(EmulatorCore.speedLimit))"
                : "\(EmulatorCore.acceleratorSpeedMHz) MHz (invalid setting)"
            unknownSpeedItem?.state = .on
        } else if let item = unknownSpeedItem {
            menu.removeItem(item)
            unknownSpeedItem = nil
        }
        for (mhz, item) in customSpeedItems {
            item.state = customZip && EmulatorCore.acceleratorSpeedMHz == mhz ? .on : .off
        }
        for item in speedMenuItems {
            item.state = item.tag == Int(EmulatorCore.speedLimit) && !customZip ? .on : .off
        }
    }

    @objc func changeCustomSpeed(_ sender: NSMenuItem) {
        guard emulatorStarted, let values = sender.representedObject as? [Int], values.count == 2,
            values[0] == EmulationSpeed.eightMHz.rawValue, values[1] > 0
        else { return }
        EmulatorCore.speedLimit = Int32(values[0])
        EmulatorCore.acceleratorSpeedMHz = Int32(values[1])
        EmulatorCore.updateAcceleratorSpeeds()
        updateSpeedChecks()
        EmulatorCore.writeConfiguration()
    }

    @objc func changeSpeed(_ sender: NSMenuItem) {
        guard emulatorStarted, let speed = EmulationSpeed(rawValue: sender.tag) else {
            return
        }
        EmulatorCore.speedLimit = Int32(speed.rawValue)
        if speed == .eightMHz {
            EmulatorCore.acceleratorSpeedMHz = 8
            EmulatorCore.updateAcceleratorSpeeds()
        }
        updateSpeedChecks()
        EmulatorCore.writeConfiguration()
    }

    @objc func togglePause(_ sender: Any?) {
        setEmulationPaused(!emulationPaused)
    }

    /// Freezes CPU execution while leaving menus, device discovery, and controller preview responsive.
    func setEmulationPaused(_ paused: Bool, reason: String? = nil) {
        guard emulatorStarted, paused != emulationPaused else { return }
        emulationPaused = paused
        if paused {
            EmulatorCore.stopKeyRepeat()
            EmulatorCore.setKeyboardFocus(false)
        } else {
            // Exclude paused wall-clock time from the core's frame pacing estimates.
            EmulatorCore.resetFrameClock()
            EmulatorCore.setKeyboardFocus(mainWindowInfo.window?.isKeyWindow == true)
        }
        let suffix = paused ? " — Paused" + (reason.map { " (\($0))" } ?? "") : ""
        mainWindowInfo.window?.title = PlayerManifest.displayName + suffix
        updatePauseMenu()
    }

    private func updatePauseMenu() {
        pauseMenuItem?.title = emulationPaused ? "Resume" : "Pause"
        pauseMenuItem?.isEnabled = emulatorStarted
        if let layout = playerMenu { layout.refresh(layout.root) }
    }

    var diskMenuItems: [(NSMenuItem, DriveAddress, Int?)] = []

    func addDiskMenus() {
        guard let layout = playerMenu else { return }
        let visible = machine.drives.count > 1 || machine.diskFiles.count > 1
        layout.replaceContents(of: .disks, with: PlayerMenuLayout.savedDisks)
        diskMenuItems = []
        guard visible else { return }
        mountedImages = [:]
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
        let contents = PlayerMenuLayout.disks(for: machine)
        layout.replaceContents(of: .disks, with: contents.entries)
        for (index, choice) in contents.choices.enumerated() {
            if let item = layout.item(.diskChoice(index)) {
                diskMenuItems.append((item, choice.0, choice.1))
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
        EmulatorCore.ejectDisk(slot: Int32(address.slot), drive: Int32(address.drive))
        mountedImages.removeValue(forKey: address)
        if let index = index {
            for (old, mounted) in Array(mountedImages) where mounted == index {
                EmulatorCore.ejectDisk(slot: Int32(old.slot), drive: Int32(old.drive))
                mountedImages.removeValue(forKey: old)
            }
            EmulatorCore.mountDisk(
                at: currentDiskDirectory.appendingPathComponent(machine.diskFiles[index]), in: address)
            mountedImages[address] = index
        }
        updateDiskChecks()
        EmulatorCore.writeConfiguration()
    }

    @objc func changeROM(_ sender: Any?) {
        guard emulatorStarted else {
            return
        }
        settingUpROM = true
        defer { settingUpROM = false }
        if let rom = ROMSetup.choose(directory: supportDirectory) {
            selectedROM = rom
            EmulatorCore.setROMPath(rom)
        }
    }

    @objc func takeScreenshot(_ sender: Any?) {
        mainWindowInfo.view?.saveScreenshot(sender)
    }

    @objc func toggleFullscreen(_ sender: Any?) {
        mainWindowInfo.window?.toggleFullScreen(sender)
    }

    @objc func showDebugger(_ sender: Any?) {
        guard emulatorStarted else { return }
        EmulatorCore.showDebugger()
        debugWindowInfo.update()
        debugWindowInfo.view?.updateDisplay()
        debugWindowInfo.window?.makeKeyAndOrderFront(sender)
    }

    @objc func resetGame(_ sender: Any?) {
        guard emulatorStarted else { return }
        EmulatorCore.restart()
        updateSpeedChecks()
    }

    @objc func showSavedDisk(_ sender: Any?) {
        NSWorkspace.shared.open(supportDirectory)
    }

    func initializeEmulator() {
        var imagePointer: EmulatorCore.Image!
        var rect = NSRect.zero

        let argc = CommandLine.argc
        let argv = CommandLine.unsafeArgv
        EmulatorCore.parseArguments(argc, arguments: argv, pathComponentsToStrip: 3)

        rect.size.width = 2560
        rect.size.height = 1440
        if let screen = NSScreen.main {
            rect = screen.frame
        }
        EmulatorCore.initialize(
            colorDepth: 24, screenWidth: Int32(rect.size.width), screenHeight: Int32(rect.size.height),
            disableScaling: Int32(1))
        if usesDirectContextDrawing {
            EmulatorCore.setBlueMask(UInt32(0x0000ff))
            EmulatorCore.setGreenMask(UInt32(0x00ff00))
            EmulatorCore.setRedMask(UInt32(0xff0000))
        } else {
            EmulatorCore.setRedMask(UInt32(0x0000ff))
            EmulatorCore.setGreenMask(UInt32(0x00ff00))
            EmulatorCore.setBlueMask(UInt32(0xff0000))
        }
        EmulatorCore.updatePalette()
        imagePointer = EmulatorCore.image(Int32(0))
        mainWindowInfo.setImage(
            imagePointer, title: PlayerManifest.displayName,
            delegate: self)
        imagePointer = EmulatorCore.image(Int32(1))
        debugWindowInfo.setImage(
            imagePointer, title: "Debugger",
            delegate: self)

        mainWindowInfo.createWindow()
        NSApp.activate(ignoringOtherApps: true)
        runEmulationLoop()
    }

    /// Schedules the next main-thread tick and pauses core execution during ROM setup.
    func runEmulationLoop() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(emulationPaused ? 33 : 1)) {
            self.runEmulationLoop()
        }
        guard !settingUpROM else {
            return
        }
        gamepadInput.update(
            active: !emulationPaused && NSApp.isActive && mainWindowInfo.window?.isKeyWindow == true
                && (EmulatorCore.joystickType == 4 || EmulatorCore.joystickType == 2)
        ) { key, isUp in
            EmulatorCore.updateKey(
                self.mainWindowInfo.imagePointer, keyCode: key, unicode: 0, isUp: isUp)
        }

        guard !emulationPaused else { return }
        refreshSnapshotDisplayIfNeeded()
        let ret = EmulatorCore.runFrame()
        if ret != 0 {
            exit(ret)
        }
        mainWindowInfo.update()
        debugWindowInfo.update()
    }
}
