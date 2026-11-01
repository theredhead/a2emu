import Cocoa
import UniformTypeIdentifiers

private let builderIntl = BuilderIntl()
private let commonIntl = CommonIntl()

/// Coordinates the builder form, media selection and creation workflows on the main thread.
@main final class Builder: NSObject, NSApplicationDelegate, BuilderFormActions {
    let form = BuilderForm()
    let aboutPanel = AppAbout(iconResourceName: "BuilderIcon")

    @objc func showAbout(_ sender: Any?) {
        aboutPanel.show()
    }

    var disks: [URL] = []
    private var snapshotWorkspace: BuilderSnapshotWorkspace?

    var startupSnapshot: URL? {
        didSet {
            form.snapshotClearButton.isHidden = startupSnapshot == nil
            refreshBootReadiness()
        }
    }

    var iconData: Data?
    var iconPicker: IconPicker?

    private var hasChosenSpeed = false
    var editingPlayer: URL?
    var pendingPlayer: URL?
    private var modifierMonitor: Any?
    private lazy var builds = PlayerBuildService(
        template: Bundle.main.resourceURL!.appendingPathComponent("PlayerTemplate.app"))

    static func main() {
        do {
            if try BuilderCommandLine.run(arguments: CommandLine.arguments) { return }
        } catch {
            fputs("\(error.localizedDescription)\n", stderr)
            exit(1)
        }

        let delegate = Builder()
        NSApplication.shared.delegate = delegate
        NSApplication.shared.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) {
            NSApplication.shared.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let app = NSMenu(title: builderIntl.appleIigsPlayerBuilder)
        let about = app.addItem(
            withTitle: builderIntl.aboutAppleIigsPlayerBuilder, action: #selector(showAbout(_:)),
            keyEquivalent: "")
        about.target = self
        app.addItem(NSMenuItem.separator())
        app.addItem(
            withTitle: commonIntl.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = app
        menu.addItem(appItem)
        NSApp.mainMenu = menu
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: commonIntl.file)
        for (title, action, key) in [
            (builderIntl.newPlayer, #selector(newPlayer(_:)), "n"),
            (builderIntl.openPlayer, #selector(openPlayerPanel(_:)), "o"),
            (builderIntl.newBlankDiskImage, #selector(createBlankDisk(_:)), ""),
        ] {
            let item = fileMenu.addItem(withTitle: title, action: action, keyEquivalent: key)
            item.target = self
        }
        fileItem.submenu = fileMenu
        menu.addItem(fileItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: builderIntl.editMenu)
        let pasteItem = editMenu.addItem(
            withTitle: builderIntl.paste, action: #selector(paste(_:)), keyEquivalent: "v")
        pasteItem.target = self
        editItem.submenu = editMenu
        menu.addItem(editItem)
        form.makeWindow(
            target: self,
            openFiles: { [weak self] in self?.acceptDroppedFiles($0) },
            openImage: { [weak self] in self?.selectIconImage($0) })
        refreshBootReadiness()
        modifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.refreshExportButton(optionHeld: event.modifierFlags.contains(.option))
            return event
        }
        refreshExportButton(optionHeld: NSEvent.modifierFlags.contains(.option))
        form.window.center()
        form.window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let pending = pendingPlayer {
            pendingPlayer = nil
            loadPlayer(pending)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        true
    }

    @objc func chooseSnapshot(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.treatsFilePackagesAsDirectories = false
        panel.allowedContentTypes = [UTType(exportedAs: "nl.theredhead.a2emu.snapshot")]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try selectSnapshot(url) } catch { showError(error.localizedDescription) }
    }

    /// Applies players and snapshots before additional disks, then uses only the first icon image.
    func acceptDroppedFiles(_ urls: [URL]) {
        var players: [URL] = []
        var snapshots: [URL] = []
        var otherFiles: [URL] = []
        var firstImage: URL?
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "app" {
                players.append(url)
            } else if ext == PlayerSnapshot.fileExtension {
                snapshots.append(url)
            } else if let type = UTType(filenameExtension: ext), type.conforms(to: .image) {
                if firstImage == nil { firstImage = url }
            } else {
                otherFiles.append(url)
            }
        }

        var ordered = players + snapshots + otherFiles
        if let image = firstImage { ordered.append(image) }
        processDroppedFiles(ordered, unhandled: [])
    }

    /// Processes a mixed drop in order, waiting for each crop before moving to the next file.
    private func processDroppedFiles(_ urls: [URL], unhandled: [URL]) {
        var failures = unhandled
        for (index, url) in urls.enumerated() {
            do {
                let ext = url.pathExtension.lowercased()
                if ext == "app" {
                    if !loadPlayer(url, reportError: false) { failures.append(url) }
                } else if ext == PlayerSnapshot.fileExtension {
                    try selectSnapshot(url)
                } else if let type = UTType(filenameExtension: ext), type.conforms(to: .image),
                    let image = NSImage(contentsOf: url)
                {
                    let remaining = Array(urls.dropFirst(index + 1))
                    let previousFailures = failures
                    selectIconImage(image) { [weak self] accepted in
                        self?.processDroppedFiles(
                            remaining, unhandled: accepted ? previousFailures : previousFailures + [url])
                    }
                    return
                } else {
                    let extensions = ["woz", "dsk", "do", "po", "2mg", "2img", "hdv", "nib"]
                    guard extensions.contains(ext),
                        (try url.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true
                    else {
                        failures.append(url)
                        continue
                    }
                    appendDroppedDisks([url])
                }
            } catch { failures.append(url) }
        }
        if !failures.isEmpty {
            showError(builderIntl.unhandledFiles(files: failures.map { $0.path }.joined(separator: "\n")))
        }
    }

    /// Expands private working copies before applying the snapshot's name, RAM and mounted drives.
    /// Failed imports leave the current form and media intact.
    func selectSnapshot(_ url: URL) throws {
        let workspace = try BuilderSnapshotWorkspace(url: url)
        let snapshot = workspace.snapshot
        let capturedMemory = workspace.expansionMemoryKB
        selectDisks(workspace.disks)
        snapshotWorkspace = workspace
        form.appName.stringValue = snapshot.gameName
        if let index = PlayerManifest.expansionMemoryChoices.firstIndex(of: capturedMemory) {
            form.memory.selectItem(at: index)
        }
        for (index, count) in form.driveCounts.enumerated() {
            let snapshotSlot = [6, 5, 7][index]
            let required =
                snapshot.mounts.filter { $0.address.slot == snapshotSlot }.map { $0.address.drive + 1 }.max()
                ?? 0
            count.selectItem(at: required)
        }
        if let boot = snapshot.mounts.first(where: { $0.diskIndex == 0 }) ?? snapshot.mounts.first,
            let index = [6, 5, 7].firstIndex(of: boot.address.slot)
        {
            form.slot.selectItem(at: index)
        }
        rebuildMounts()
        for index in disks.indices {
            let address = snapshot.mounts.first { $0.diskIndex == index }?.address
            form.mountChoices[index].selectItem(
                at: address.flatMap { form.configuredDrives.firstIndex(of: $0) }.map { $0 + 1 } ?? 0)
        }
        form.memory.isEnabled = false
        startupSnapshot = url
        form.speed.isEnabled = false
        form.speed.toolTip = builderIntl.snapshotSpeedHint
        form.snapshotLabel.stringValue = snapshot.title
        form.snapshotLabel.toolTip = url.path
    }

    private func removeSnapshotWorkingDisks() {
        snapshotWorkspace = nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeSnapshotWorkingDisks()
    }

    @objc func clearSnapshot(_ sender: Any?) {
        startupSnapshot = nil
        form.speed.isEnabled = true
        form.memory.isEnabled = true
        form.speed.toolTip = nil
        form.snapshotLabel.stringValue = builderIntl.normalStartup
        form.snapshotLabel.toolTip = nil
    }

    @objc func createBlankDisk(_ sender: Any?) {
        let panel = BlankDiskCreationPanel()
        guard let selection = panel.choose(allowAdding: startupSnapshot == nil) else { return }

        let url = selection.url
        do {
            guard !disks.contains(where: { $0.standardizedFileURL == url.standardizedFileURL }) else {
                throw PlayerManifest.failure(
                    builderIntl.selectedDiskOverwriteError)
            }
            try selection.image.write(to: url, format: selection.format)
            if selection.addToPlayer {
                if disks.isEmpty {
                    selectDisks([url])
                } else {
                    disks.append(url)
                    rebuildMounts()
                    form.mountChoices.last?.selectItem(at: 0)
                    refreshBootReadiness()
                    form.summary.stringValue = builderIntl.diskImagesSelected(count: disks.count)
                }
            }
        } catch { showError(error.localizedDescription) }
    }

    @objc func chooseDisks(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = ["woz", "dsk", "do", "po", "2mg", "2img", "hdv", "nib"].compactMap {
            UTType(filenameExtension: $0)
        }
        guard panel.runModal() == .OK else {
            return
        }

        selectDisks(panel.urls)
    }

    /// Adds dropped media without changing existing disk names, mounts or machine settings.
    func appendDroppedDisks(_ urls: [URL]) {
        var additions: [URL] = []
        var knownURLs = Set(disks.map { $0.standardizedFileURL })
        for url in urls {
            if knownURLs.insert(url.standardizedFileURL).inserted {
                additions.append(url)
            }
        }
        guard !additions.isEmpty else { return }
        if disks.isEmpty {
            selectDisks(additions)
            return
        }

        let previousMounts = form.mountChoices.map { $0.indexOfSelectedItem }

        let previousSlot = form.slot.indexOfSelectedItem
        let previousSpeed = form.speed.indexOfSelectedItem
        // The snapshot describes an exact disk set; retain its working copies as selected media.
        clearSnapshot(nil)
        disks.append(contentsOf: additions)
        rebuildMounts()
        form.slot.selectItem(at: previousSlot)
        form.speed.selectItem(at: previousSpeed)
        for (index, choice) in form.mountChoices.enumerated() {
            choice.selectItem(at: previousMounts.indices.contains(index) ? previousMounts[index] : 0)
        }
        form.summary.stringValue = builderIntl.diskImagesSelected(count: disks.count)
        refreshBootReadiness()
    }

    /// Selects the initial boot drive from the first image; drive controls remain editable.
    func selectDisks(_ urls: [URL]) {
        guard let bootImage = urls.first else { return }
        clearSnapshot(nil)
        removeSnapshotWorkingDisks()
        let previousDefault = disks.first?.deletingPathExtension().lastPathComponent
        form.diskNameFields = []
        form.mountChoices = []
        disks = urls
        form.summary.stringValue = builderIntl.diskImagesSelected(count: disks.count)
        if form.appName.stringValue.isEmpty || form.appName.stringValue == previousDefault {
            form.appName.stringValue = disks[0].deletingPathExtension().lastPathComponent
        }
        if let index = [6, 5, 7].firstIndex(of: DiskImageDevice.detect(bootImage).slot) {
            form.slot.selectItem(at: index)
        }
        startupChanged(nil)
    }

    @objc func startupChanged(_ sender: Any?) {
        form.mountChoices = []
        for (index, count) in form.driveCounts.enumerated() {
            count.selectItem(at: index == form.slot.indexOfSelectedItem ? 1 : 0)
        }
        rebuildMounts()
    }

    @objc func mountChanged(_ sender: Any?) {
        refreshBootReadiness()
    }

    /// Reports only the selected slot's first drive; later disks cannot make that drive bootable.
    func refreshBootReadiness() {
        let index = form.slot.indexOfSelectedItem
        let mounts = form.mountChoices.enumerated().compactMap { index, choice -> DiskMount? in
            let drive = choice.indexOfSelectedItem - 1
            guard form.listedDrives.indices.contains(drive) else { return nil }
            return DiskMount(diskIndex: index, address: form.listedDrives[drive])
        }

        let readiness = BootReadiness.evaluate(
            disks: disks,
            bootSlot: [0, 1, 2].contains(index) ? [6, 5, 7][index] : nil,
            drives: form.configuredDrives, mounts: mounts, restoresSnapshot: startupSnapshot != nil,
            inspect: { disk, slot in
                return DiskImageDevice.detect(disk).slot == slot
                    ? DiskBootability.inspect(disk) : .notBootable
            })
        form.displayBootReadiness(readiness)
    }

    @objc func speedChanged(_ sender: Any?) {
        hasChosenSpeed = true
    }

    /// Only untouched defaults follow the boot device; explicit and saved speeds take precedence.
    private func updateAutomaticSpeed() {
        guard !disks.isEmpty, !hasChosenSpeed, startupSnapshot == nil, form.slot.indexOfSelectedItem >= 0
        else {
            return
        }

        let bootSlot = [6, 5, 7][form.slot.indexOfSelectedItem]
        let defaultSpeed: EmulationSpeed = bootSlot == 6 ? .oneMHz : .twoPointEightMHz
        if let index = EmulationSpeed.allCases.firstIndex(of: defaultSpeed) {
            form.speed.selectItem(at: index)
        }
    }

    func rebuildMounts() {
        form.rebuildMounts(disks: disks, target: self)
        updateAutomaticSpeed()
        refreshBootReadiness()
    }

    @objc func drivesChanged(_ sender: Any?) {
        rebuildMounts()
    }

    @objc func paste(_ sender: Any?) {
        if let image = NSImage(pasteboard: .general) {
            selectIconImage(image)
        } else if let text = form.window.firstResponder as? NSText {
            text.paste(sender)
        }
    }

    func selectIconImage(_ image: NSImage, completion: ((Bool) -> Void)? = nil) {
        guard image.size.width > 0, image.size.height > 0 else {
            completion?(false)
            return
        }
        if image.size.width == image.size.height {
            let crop = SquareCropView(frame: NSRect(x: 0, y: 0, width: 300, height: 300))
            crop.image = image
            if let data = crop.png() {
                iconData = data
                form.iconPreview.image = NSImage(data: data)
                completion?(true)
            } else {
                completion?(false)
            }
            return
        }

        let picker = IconPicker()
        iconPicker = picker
        picker.cropClosed = completion
        picker.showCrop(image: image) { [weak self] data in
            self?.iconData = data
            self?.form.iconPreview.image = NSImage(data: data)
        }
    }

    @objc func chooseIcon(_ sender: Any?) {
        guard let disk = disks.first else {
            showError(builderIntl.chooseADiskFirst)
            return
        }

        let picker = IconPicker()
        iconPicker = picker
        let name = form.appName.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchName = name.isEmpty ? disk.deletingPathExtension().lastPathComponent : name
        picker.show(searchName: searchName) { [weak self] data in
            self?.iconData = data
            self?.form.iconPreview.image = NSImage(data: data)
        }
    }

    private func refreshExportButton(optionHeld: Bool) {
        form.exportButton.title =
            optionHeld
            ? builderIntl.runNow
            : (editingPlayer == nil ? builderIntl.createPlayer : commonIntl.save)
        form.exportButton.toolTip = builderIntl.runNowHint
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        refreshExportButton(optionHeld: NSEvent.modifierFlags.contains(.option))
        refreshBootReadiness()
    }

    @objc func createPlayer(_ sender: Any?) {
        let runNow = NSEvent.modifierFlags.contains(.option)
        guard !disks.isEmpty else {
            showError(builderIntl.chooseADiskFirst)
            return
        }

        let settings: PlayerBuildConfiguration
        do {
            settings = try form.configuration(disks: disks, icon: iconData, snapshot: startupSnapshot)
            try settings.validate()
            if runNow {
                try builds.preview(settings)
                return
            }
        } catch {
            showError(error.localizedDescription)
            return
        }
        if let existing = editingPlayer {
            guard
                !NSWorkspace.shared.runningApplications.contains(where: {
                    $0.bundleURL?.standardizedFileURL == existing.standardizedFileURL
                })
            else {
                showError(builderIntl.quitPlayerBeforeSavingError)
                return
            }
            do {
                try builds.update(settings, at: existing)
                loadPlayer(existing)
                form.summary.stringValue = builderIntl.savedChangesTo(filename: existing.lastPathComponent)
            } catch {
                showError(error.localizedDescription)
            }
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = settings.name + ".app"
        guard panel.runModal() == .OK, let output = panel.url else {
            return
        }
        do {
            try builds.create(settings, at: output)
            NSWorkspace.shared.activateFileViewerSelecting([output])
        } catch {
            showError(error.localizedDescription)
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard filenames.count == 1 else {
            sender.reply(toOpenOrPrint: .failure)
            return
        }

        let url = URL(fileURLWithPath: filenames[0])
        if form.window == nil {
            pendingPlayer = url
        } else {
            loadPlayer(url)
        }
        sender.reply(toOpenOrPrint: .success)
    }

    @objc func openPlayerPanel(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        loadPlayer(url)
    }

    @objc func newPlayer(_ sender: Any?) {
        editingPlayer = nil
        removeSnapshotWorkingDisks()
        clearSnapshot(nil)
        disks = []
        form.diskNameFields = []
        form.mountChoices = []
        iconData = nil
        form.iconPreview.image = NSImage(named: NSImage.Name("PlayerIcon"))
        form.appName.stringValue = ""
        form.fullScreen.state = .off
        hasChosenSpeed = false
        form.memory.selectItem(at: PlayerManifest.expansionMemoryChoices.firstIndex(of: 8192)!)
        form.speed.selectItem(at: EmulationSpeed.allCases.firstIndex(of: .twoPointEightMHz)!)
        form.slot.selectItem(at: 0)
        for (i, count) in form.driveCounts.enumerated() {
            count.selectItem(at: i == 0 ? 1 : 0)
        }
        form.heading.stringValue = builderIntl.createPlayerHeading
        refreshExportButton(optionHeld: NSEvent.modifierFlags.contains(.option))
        form.window.title = builderIntl.appleIigsPlayerBuilder
        form.summary.stringValue = builderIntl.emptyPlayerHint
        rebuildMounts()
    }

    @discardableResult
    func loadPlayer(_ url: URL, reportError: Bool = true) -> Bool {
        do {
            let document = try BuilderPlayerDocument(url: url)
            removeSnapshotWorkingDisks()
            disks = document.disks
            form.diskNameFields = []
            form.mountChoices = []
            form.displaySettings(document)
            hasChosenSpeed = true
            startupSnapshot = document.snapshot
            form.displayMedia(document, target: self)
            refreshBootReadiness()
            iconData = document.icon
            form.iconPreview.image =
                iconData.flatMap { NSImage(data: $0) } ?? NSWorkspace.shared.icon(forFile: url.path)
            form.heading.stringValue = builderIntl.editThisAppleIigsPlayer
            editingPlayer = url
            refreshExportButton(optionHeld: NSEvent.modifierFlags.contains(.option))
            form.window.title = builderIntl.edit(filename: url.lastPathComponent)
            form.summary.stringValue = builderIntl.editing(filename: url.lastPathComponent)
            form.window.makeKeyAndOrderFront(nil)
            return true
        } catch {
            if reportError { showError(error.localizedDescription) }
            return false
        }
    }

    func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = builderIntl.couldNotUpdatePlayer
        alert.informativeText = message
        alert.runModal()
    }
}
