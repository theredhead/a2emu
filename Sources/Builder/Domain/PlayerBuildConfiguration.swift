import Foundation

/// Immutable build intent captured from the form, independent of AppKit and export/launch side effects.
struct PlayerBuildConfiguration {
    let name: String
    let disks: [URL]
    let bootSlot: Int
    let icon: Data?
    let mounts: [DiskMount]
    let diskNames: [String]
    let drives: [DriveAddress]
    let speed: EmulationSpeed
    let fullScreen: Bool
    let startupSnapshot: URL?
    let expansionMemoryKB: Int

    func validate() throws {
        _ = try PlayerManifest.checkedName(name)
        try PlayerManifest.make(
            disks: disks.map { $0.lastPathComponent }, slot: bootSlot,
            mounts: mounts, diskNames: diskNames, availableDrives: drives,
            initialSpeed: speed, startInFullScreen: fullScreen
        ).validate()
    }
}
