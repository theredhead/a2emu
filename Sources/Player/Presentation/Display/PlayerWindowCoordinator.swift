import Cocoa

/// Owns window focus, fullscreen transitions and integer sizing independently of startup, storage and menus.
/// The emulator image handles are borrowed from the two window presenters and used only on the main thread.
final class PlayerWindowCoordinator: NSObject, NSWindowDelegate {
    private let main: EmulatorWindow
    private let debug: EmulatorWindow

    init(main: EmulatorWindow, debug: EmulatorWindow) {
        self.main = main
        self.debug = debug
        super.init()
    }

    func windowInfo(for window: NSWindow) -> EmulatorWindow {
        return main.window == window ? main : debug
    }

    func windowDidBecomeKey(_ notification: Notification) {
        if let w = notification.object as? NSWindow {
            if w == main.window {
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
        if window == main.window, integerResize, !changingFullScreen,
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

    var nativeDisplaySize: NSSize {
        NSSize(
            width: max(1, Int(EmulatorCore.emulatedImageWidth(main.imagePointer))),
            height: max(1, Int(EmulatorCore.emulatedImageHeight(main.imagePointer))))
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
        guard integerResize, let window = main.window, !changingFullScreen,
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
        if main.window == window {
            // User has clicked the close box on the main emulator
            //  window.  Just exit the app
            NSApp.terminate(window)
            return false  // Keep the window open if quitting is cancelled.
        } else {
            EmulatorCore.setImageActivity(info.imagePointer, active: Int32(0))
            info.update()
            return false
        }
    }
}
