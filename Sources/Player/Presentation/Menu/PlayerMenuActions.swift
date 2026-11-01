import Cocoa

/// Objective-C command surface shared by declarative menus and the application coordinator.
@objc protocol PlayerMenuActions: NSObjectProtocol {
    func showAbout(_ sender: AnyObject)

    func changeROM(_ sender: Any?)

    func showDebugger(_ sender: Any?)

    func toggleFullscreen(_ sender: Any?)

    func toggleIntegerResize(_ sender: NSMenuItem)

    func takeScreenshot(_ sender: Any?)

    func togglePause(_ sender: Any?)

    func resetGame(_ sender: Any?)

    func showSnapshots(_ sender: Any?)

    func saveTemporaryMedia(_ sender: Any?)

    func showSavedDisk(_ sender: Any?)

    func changeSpeed(_ sender: NSMenuItem)

    func changeControls(_ sender: NSMenuItem)

    func configureControls(_ sender: Any?)

    func swapDisk(_ sender: NSMenuItem)
}
