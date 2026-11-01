import Foundation

/// Commands and catalogue access used by the snapshot browser, independent of the concrete app delegate.
protocol SnapshotBrowserSession: AnyObject {
    var snapshotsDirectory: URL { get }

    var snapshotLibrary: SnapshotLibrary { get }

    func setSnapshotBrowserOpen(_ open: Bool)

    func setSnapshotFinderIcon(at url: URL)

    func saveSnapshot(title: String) throws -> URL

    func restoreSnapshot(at url: URL, applyAdditionalStartupMounts: Bool) throws

    func snapshotFitsDiskSet(_ snapshot: PlayerSnapshot) -> Bool

    func focusGameWindow()
}
