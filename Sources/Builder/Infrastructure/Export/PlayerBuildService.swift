import Foundation

/// Performs validated exports, replacements and disposable previews using an explicitly supplied template/launcher.
struct PlayerBuildService {
    let template: URL
    let manager: FileManager
    let launch: (URL, URL) throws -> Void

    init(
        template: URL, manager: FileManager = .default,
        launch: @escaping (URL, URL) throws -> Void = TemporaryPlayerLauncher.launch
    ) {
        self.template = template
        self.manager = manager
        self.launch = launch
    }

    func create(_ settings: PlayerBuildConfiguration, at destination: URL, identifier: String? = nil) throws {
        try settings.validate()
        try PlayerExporter.export(
            disks: settings.disks, slot: settings.bootSlot,
            template: template, destination: destination, icon: settings.icon, displayName: settings.name,
            mounts: settings.mounts, diskNames: settings.diskNames, availableDrives: settings.drives,
            initialSpeed: settings.speed, startInFullScreen: settings.fullScreen,
            bundleIdentifier: identifier, startupSnapshot: settings.startupSnapshot,
            expansionMemoryKB: settings.expansionMemoryKB)
    }

    func update(_ settings: PlayerBuildConfiguration, at destination: URL) throws {
        try settings.validate()
        try PlayerExporter.update(
            app: destination, disks: settings.disks, slot: settings.bootSlot,
            icon: settings.icon, displayName: settings.name, mounts: settings.mounts,
            diskNames: settings.diskNames, availableDrives: settings.drives, initialSpeed: settings.speed,
            startInFullScreen: settings.fullScreen, startupSnapshot: settings.startupSnapshot,
            expansionMemoryKB: settings.expansionMemoryKB)
    }

    /// The launcher owns exit cleanup; failed export/launch removes all partially prepared preview files.
    func preview(_ settings: PlayerBuildConfiguration) throws {
        let directory = manager.temporaryDirectory.appendingPathComponent("a2-preview-" + UUID().uuidString)
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            let app = directory.appendingPathComponent(settings.name + ".app")
            try create(
                settings, at: app,
                identifier: "nl.theredhead.applejuicer.juicebox.preview." + UUID().uuidString)
            try launch(app, directory)
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }
}
