import Foundation

/// The running-session state and commands needed by a display view; views never discover the app delegate.
protocol PlayerViewSession: AnyObject {
    var emulatorStarted: Bool { get }

    var emulationPaused: Bool { get }

    func setDialogOpen(_ open: Bool, reason: String)

    func showSnapshots(_ sender: Any?)

    func handleDroppedDisks(_ urls: [URL], permanently: Bool) throws -> Bool
}
