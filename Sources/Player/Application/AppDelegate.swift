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

private let commonIntl = CommonIntl()
private let playerIntl = PlayerIntl()

/// Selects direct context-memory rendering instead of the default bitmap-image path.
let usesDirectContextDrawing = false

/// Coordinates player startup, saved configuration, menus, and the main-thread emulation loop.
@main
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, PlayerViewSession, SnapshotBrowserSession,
    PlayerMenuActions
{
    static func main() {
        if let identifier = Bundle.main.bundleIdentifier,
            identifier.hasPrefix("nl.theredhead.applejuicer.juicebox")
        {
            // Read existing controller preferences until the user saves settings in the new domain.
            UserDefaults.standard.addSuite(
                named: identifier.replacingOccurrences(
                    of: "nl.theredhead.applejuicer.juicebox", with: "nl.theredhead.a2emu-player",
                    options: .anchored))
        }

        let delegate = AppDelegate()
        NSApplication.shared.delegate = delegate
        withExtendedLifetime(delegate) {
            _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
        }
    }

    var mainWindowInfo = EmulatorWindow()
    lazy var windows = PlayerWindowCoordinator(main: mainWindowInfo, debug: debugWindowInfo)
    var integerResizeItem: NSMenuItem?
    var debugWindowInfo = EmulatorWindow()

    let gamepadInput = GamepadInput()
    let aboutPanel = AppAbout()

    @objc func showAbout(_: AnyObject) {
        setDialogOpen(true, reason: "About")
        defer { setDialogOpen(false, reason: "About") }
        aboutPanel.creditsVisibilityChanged = { [weak self] open in
            self?.setDialogOpen(open, reason: "Credits")
        }
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
                    try restoreSnapshot(at: startup, applyAdditionalStartupMounts: true)
                } catch {
                    setEmulationPaused(true, reason: "Startup snapshot could not be restored")
                    let alert = NSAlert()
                    alert.messageText = playerIntl.couldNotRestoreStartupSnapshot
                    alert.informativeText = playerIntl.startupRecoveryHint(
                        errorDescription: error.localizedDescription)
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
            alert.messageText = playerIntl.couldNotStartEmulator
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApp.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard emulatorStarted else { return .terminateNow }
        setDialogOpen(true, reason: "Save Temporary Media")
        defer { setDialogOpen(false, reason: "Save Temporary Media") }
        do {
            return try confirmTemporaryMediaQuit() ? .terminateNow : .terminateCancel
        } catch {
            showTemporaryMediaSaveError(error)
            return .terminateCancel
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        defer {
            if let directory = temporaryRunDirectory { try? FileManager.default.removeItem(at: directory) }
        }
        guard emulatorStarted else {
            return
        }
        writePlayerConfiguration()
        // Save mounted drives before ejecting to flush disk writes on shutdown.
        for address in DriveAddress.all {
            EmulatorCore.ejectDisk(slot: Int32(address.slot), drive: Int32(address.drive))
        }
        if let directory = temporaryDiskDirectory { try? FileManager.default.removeItem(at: directory) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(
        _ theApplication: NSApplication
    ) -> Bool {
        // Application will close if main window is closed
        return true
    }

    var playerMenu: PlayerMenu?
    private(set) var advancedMenus = false
    var menuModifierFlags: () -> NSEvent.ModifierFlags = { NSEvent.modifierFlags }

    func setUpMenus() {
        let entries = PlayerMenuLayout.main(
            appName: PlayerManifest.displayName,
            isRunning: { [weak self] in self?.emulatorStarted == true },
            canTogglePause: { [weak self] in
                self?.emulatorStarted == true && self?.pauseState.canToggleManualPause == true
            },
            showAdvanced: { [weak self] in self?.advancedMenus == true },
            canSaveTemporaryMedia: { [weak self] in self?.temporaryMediaHaveChanges == true })
        let layout = PlayerMenu(entries: entries, target: self, menuDelegate: self)
        playerMenu = layout
        NSApp.mainMenu = layout.root
        pauseMenuItem = layout.item(.pause)
        integerResizeItem = layout.item(.integerResize)
        speedMenu.reset()
        controlMenuItems = []
        diskMenu.reset()
        controllerStatusItem = nil
        updatePauseMenu()
        integerResizeItem?.state = windows.integerResize ? .on : .off
    }

    var mainWindow: NSWindow!
    var mainView: MainView!

    var snapshotDiskDirectory: URL?
    var snapshotNeedsVideoRefresh = false
    var snapshotBrowser: SnapshotBrowser?

    /// Only preview bundles in the system temporary directory may remove their containing folder.
    private var temporaryRunDirectory: URL? {
        guard CommandLine.arguments.contains("--temporary-player") else { return nil }

        let directory = Bundle.main.bundleURL.deletingLastPathComponent().resolvingSymlinksInPath()
        guard directory.lastPathComponent.hasPrefix("a2-preview-"),
            directory.deletingLastPathComponent()
                == FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        else { return nil }
        return directory
    }

    let storage = PlayerStorage()
    let configurationStore = PlayerConfigurationStore()
    var supportDirectory: URL!
    var selectedROM: URL?
    var emulatorStarted = false
    var settingUpROM = false
    private(set) var emulationPaused = false
    private var pauseState = EmulationPause()
    private var pauseMenuItem: NSMenuItem?
    var machine: PlayerManifest!

    /// Seeds missing saved disks and applies revised export defaults while preserving other settings.
    /// Throws on invalid manifests or file errors; ROM cancellation leaves startup incomplete.
    func prepareGameFiles() throws {
        let opened = try storage.open(
            resource: Bundle.main.resourceURL!,
            identifier: Bundle.main.bundleIdentifier!, previewDirectory: temporaryRunDirectory)
        supportDirectory = opened.directory
        machine = opened.manifest
        try loadImportedDisks()
        selectedROM = try ROMLibrary.existing(directory: supportDirectory)
        if selectedROM == nil {
            selectedROM = ROMSetup.choose(directory: supportDirectory)
        }
        guard let rom = selectedROM else {
            return
        }

        let config = try configurationStore.prepare(manifest: machine, rom: rom, directory: supportDirectory)
        EmulatorCore.setConfigurationPath(config)
    }

    private var diskLibrary: ImportedDiskLibrary {
        return ImportedDiskLibrary(directory: supportDirectory, workingDirectory: currentDiskDirectory)
    }

    /// Restores the saved disk index; the storage boundary validates and decodes it.
    func loadImportedDisks() throws {
        machine = try diskLibrary.load(into: machine)
    }

    /// Coordinates the storage transaction with live menu/mount reconciliation; prompts stay in the UI.
    @discardableResult
    func importDiskImages(_ urls: [URL], rename: ((String) -> String?)? = nil) throws -> Bool {
        guard
            let updated = try diskLibrary.importImages(
                urls, into: machine,
                rename: { name in
                    return rename?(name) ?? (rename == nil ? self.requestDiskImportName(name) : nil)
                })
        else { return false }
        machine = updated
        var mounted = mountedImages
        if emulatorStarted {
            mounted = [:]
            for address in machine.drives {
                if let path = EmulatorCore.mountedDiskPath(
                    slot: Int32(address.slot), drive: Int32(address.drive)),
                    let index = machine.diskFiles.firstIndex(of: URL(fileURLWithPath: path).lastPathComponent)
                {
                    mounted[address] = index
                }
            }
        }
        addDiskMenus()
        mountedImages = mounted
        updateDiskChecks()
        return true
    }

    /// Renaming owns a temporary pause without releasing an existing manual or dialog pause.
    func requestDiskImportName(_ name: String) -> String? {
        setDialogOpen(true, reason: "Rename Disk")
        defer { setDialogOpen(false, reason: "Rename Disk") }

        let alert = PlayerDiskAlert()
        alert.messageText = playerIntl.chooseADifferentDiskName
        alert.informativeText =
            playerIntl.diskNameCollision(name: name)
        alert.addButton(withTitle: playerIntl.useThisName)
        alert.addButton(withTitle: commonIntl.cancel)
        let field = NSTextField(string: name)
        field.frame = NSRect(x: 0, y: 0, width: 360, height: 24)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    var mountedImages: [DriveAddress: Int] = [:]
    var temporaryDiskDirectory: URL?
    var temporaryDiskNames: Set<String> = []
    var temporaryDiskPaths: [String: URL] = [:]
    var temporaryDiskOriginalPaths: [String: URL] = [:]
    var temporaryDiskSavedHashes: [String: String] = [:]
    var temporaryMediaHaveChanges = false
    var temporaryDrivePaths: [DriveAddress: String] = [:]
    let speedMenu = PlayerSpeedMenu()

    func addSpeedMenu() {
        if let layout = playerMenu { speedMenu.configure(in: layout) }
    }

    /// Supplies current core values to the independently owned speed-menu presentation.
    func updateSpeedChecks() {
        speedMenu.refresh(
            speedLimit: EmulatorCore.speedLimit,
            acceleratorSpeedMHz: EmulatorCore.acceleratorSpeedMHz,
            target: self, action: #selector(changeCustomSpeed(_:)))
    }

    let controllerMappingPanel = ControllerMappingPanel()

    @objc func configureControls(_ sender: Any?) {
        setDialogOpen(true, reason: "Controller Settings")
        controllerMappingPanel.didClose = { [weak self] in
            self?.setDialogOpen(false, reason: "Controller Settings")
        }
        controllerMappingPanel.show(
            mapping: gamepadInput.mapping,
            controllers: { [weak self] in self?.gamepadInput.availableControllers() ?? [] },
            selectedControllerID: gamepadInput.selectedControllerID,
            preview: { [weak self] mapping, controllerID in
                self?.gamepadInput.previewState(mapping: mapping, controllerID: controllerID)
            },
            supportedButtons: { [weak self] controllerID in
                self?.gamepadInput.supportedButtonIndices(controllerID: controllerID)
            },
            completion: { [weak self] mapping, controllerID in
                self?.gamepadInput.selectedControllerID = controllerID
                self?.gamepadInput.mapping = mapping
                EmulatorCore.joystickType = 4
                self?.writePlayerConfiguration()
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
        writePlayerConfiguration()
    }

    func menuWillOpen(_ menu: NSMenu) {
        // Latch the mode when opening a top-level menu; submenus inherit it after Option is released.
        if menu.supermenu === playerMenu?.root {
            advancedMenus = menuModifierFlags().contains(.option)
        }
        if let disksMenu = playerMenu?.submenu(.disks),
            menu === disksMenu || menu.supermenu === disksMenu
        {
            if emulatorStarted { refreshMountedImagesFromCore() }
            updateDiskChecks()
            updateTemporaryMediaMenu()
        }
        updatePauseMenu()
        updateSpeedChecks()
        for item in controlMenuItems {
            item.state = item.tag == Int(EmulatorCore.joystickType) ? .on : .off
        }
        controllerStatusItem?.title = gamepadInput.controllerName
    }

    @objc func changeCustomSpeed(_ sender: NSMenuItem) {
        guard emulatorStarted, let values = sender.representedObject as? [Int], values.count == 2,
            values[0] == EmulationSpeed.eightMHz.rawValue, values[1] > 0
        else { return }
        EmulatorCore.speedLimit = Int32(values[0])
        EmulatorCore.acceleratorSpeedMHz = Int32(values[1])
        EmulatorCore.updateAcceleratorSpeeds()
        updateSpeedChecks()
        writePlayerConfiguration()
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
        writePlayerConfiguration()
    }

    @objc func togglePause(_ sender: Any?) {
        guard pauseState.canToggleManualPause else { return }
        setEmulationPaused(!emulationPaused)
    }

    /// Records a pause independently of temporary windows, including disconnects and recovery failures.
    func setEmulationPaused(_ paused: Bool, reason: String? = nil) {
        guard emulatorStarted else { return }
        pauseState.setManual(paused, reason: reason)
        updateEmulationPause()
    }

    /// Releases only the browser's pause; manual and other dialog pauses remain in effect.
    func setSnapshotBrowserOpen(_ open: Bool) {
        setDialogOpen(open, reason: "Snapshots")
    }

    /// Each dialog owns its pause so overlapping windows cannot resume each other.
    func setDialogOpen(_ open: Bool, reason: String) {
        guard emulatorStarted else { return }
        pauseState.setDialog(open, reason: reason)
        updateEmulationPause()
    }

    private func updateEmulationPause() {
        let paused = pauseState.isPaused
        if paused != emulationPaused {
            emulationPaused = paused
            if paused {
                EmulatorCore.stopKeyRepeat()
                EmulatorCore.setKeyboardFocus(false)
            } else {
                // Exclude paused wall-clock time from the core's frame pacing estimates.
                EmulatorCore.resetFrameClock()
                EmulatorCore.setKeyboardFocus(mainWindowInfo.window?.isKeyWindow == true)
            }
        }

        let reason = pauseState.reason
        mainWindowInfo.window?.title =
            paused
            ? playerIntl.pausedTitle(gameName: PlayerManifest.displayName, reason: reason)
            : PlayerManifest.displayName
        updatePauseMenu()
    }

    private func updatePauseMenu() {
        pauseMenuItem?.title = emulationPaused ? commonIntl.resume : commonIntl.pause
        pauseMenuItem?.isEnabled = emulatorStarted && pauseState.canToggleManualPause
        if let layout = playerMenu { layout.refresh(layout.root) }
    }

    let diskMenu = PlayerDiskMenu()

    func addDiskMenus() {
        guard let layout = playerMenu else { return }
        guard
            diskMenu.configure(
                in: layout, manifest: machine,
                canSave: { [weak self] in self?.temporaryMediaHaveChanges == true })
        else { return }
        mountedImages = configurationStore.mounts(manifest: machine, directory: supportDirectory)
        updateDiskChecks()
    }

    /// Supplies current mounts and media compatibility to the disk-menu presentation.
    func updateDiskChecks() {
        diskMenu.refresh(
            mountedImages: mountedImages,
            slots: machine.diskFiles.map { DiskImageDevice.detect(diskURL(named: $0)).slot })
    }

    @objc func swapDisk(_ sender: NSMenuItem) {
        guard emulatorStarted, diskMenu.diskMenuItems.indices.contains(sender.tag) else {
            return
        }

        updateDiskChecks()
        guard !diskMenu.diskMenuItems[sender.tag].0.isHidden else { return }

        let (_, address, index) = diskMenu.diskMenuItems[sender.tag]
        if let index = index, temporaryDiskNames.contains(machine.diskFiles[index]) {
            if temporaryDrivePaths[address] == nil {
                temporaryDrivePaths[address] =
                    mountedImages[address].map {
                        diskURL(named: machine.diskFiles[$0]).path
                    } ?? ""
            }
        } else {
            temporaryDrivePaths.removeValue(forKey: address)
        }
        EmulatorCore.ejectDisk(slot: Int32(address.slot), drive: Int32(address.drive))
        mountedImages.removeValue(forKey: address)
        if let index = index {
            EmulatorCore.mountDisk(at: diskURL(named: machine.diskFiles[index]), in: address)
            mountedImages[address] = index
        }
        updateDiskChecks()
        writePlayerConfiguration()
    }

    @objc func changeROM(_ sender: Any?) {
        guard emulatorStarted else {
            return
        }
        setDialogOpen(true, reason: "ROM Setup")
        defer { setDialogOpen(false, reason: "ROM Setup") }
        settingUpROM = true
        defer { settingUpROM = false }
        if let rom = ROMSetup.choose(directory: supportDirectory) {
            selectedROM = rom
            EmulatorCore.setROMPath(rom)
        }
    }

    func handleDroppedDisks(_ urls: [URL], permanently: Bool) throws -> Bool {
        return try mountDroppedDisks(urls, permanently: permanently)
    }

    func focusGameWindow() {
        mainWindowInfo.window?.makeKeyAndOrderFront(nil)
    }

    @objc func takeScreenshot(_ sender: Any?) {
        mainWindowInfo.view?.saveScreenshot(sender)
    }

    @objc func toggleIntegerResize(_ sender: NSMenuItem) {
        windows.toggleIntegerResize(sender)
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

        EmulatorCore.parseLaunchArguments(pathComponentsToStrip: 3)

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
            coordinator: windows, session: self)
        imagePointer = EmulatorCore.image(Int32(1))
        debugWindowInfo.setImage(
            imagePointer, title: playerIntl.debugger,
            coordinator: windows, session: self)

        mainWindowInfo.createWindow()
        NSApp.activate(ignoringOtherApps: true)
        gamepadInput.mouseEvent = { [weak self] dx, dy, pressed in
            guard let self = self else { return }
            _ = EmulatorCore.updateMouse(
                self.mainWindowInfo.imagePointer, x: dx, y: dy,
                buttons: pressed == true ? 1 : 0, validButtons: 0x1000 | (pressed == nil ? 0 : 1))
        }
        runEmulationLoop()
    }

    /// Schedules main-thread input updates and runs the core only while emulation is unpaused.
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
