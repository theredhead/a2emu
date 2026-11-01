// $KmKId: MainView.swift,v 1.42 2024-09-15 13:55:35+00 kentd Exp $

//	Copyright 2019-2024 by Kent Dickey
//	This code is covered by the GNU GPL v3
//	See the file COPYING.txt or https://www.gnu.org/licenses/
//

import AudioToolbox
import Cocoa
import CoreGraphics

private let playerViewIntl = PlayerViewIntl()

/// Displays an emulator-owned image and forwards AppKit keyboard and mouse input.
class MainView: NSView {
    weak var session: PlayerViewSession?
    var framebuffer: EmulatorFramebuffer?
    private let screenshots = ScreenshotStore()
    var currentModifiers: UInt = 0
    var mouseMovedSinceWarp: Bool = false
    var pointerWarpState: Int32 = 0
    var pointerHiddenState: Int32 = 0

    /// Borrowed from the C core; the emulator retains ownership.
    var imagePointer: EmulatorCore.Image!
    var closed: Bool = false
    // Retain the sound until playback finishes; system resources can be absent on future macOS versions.
    private let screenshotSound = NSSound(
        contentsOfFile:
            "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif",
        byReference: true)

    let commandModifierMask = UInt(NSEvent.ModifierFlags.command.rawValue)
    let controlModifierMask = UInt(NSEvent.ModifierFlags.control.rawValue)
    let shiftModifierMask = NSEvent.ModifierFlags.shift.rawValue
    let capsLockModifierMask = NSEvent.ModifierFlags.capsLock.rawValue
    let optionModifierMask = NSEvent.ModifierFlags.option.rawValue

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard session?.emulatorStarted == true else { return [] }
        return .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let player = session, player.emulatorStarted,
            let urls = sender.draggingPasteboard().readObjects(
                forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        else { return false }
        player.setDialogOpen(true, reason: "Import Disks")
        defer { player.setDialogOpen(false, reason: "Import Disks") }
        do {
            let permanent = NSEvent.modifierFlags.contains(.option)
            guard try player.handleDroppedDisks(urls, permanently: permanent) else { return false }
            return true
        } catch {
            let alert = PlayerDiskAlert()
            alert.messageText = playerViewIntl.couldNotAddDisks
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return false
        }
    }

    func windowDidResize(_ notification: Notification) {
        print("DID RESIZE")
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Host shortcuts go through the menu, with keyDown as a fallback.
        if event.keyCode == 120 || event.keyCode == 99 { return false }
        guard session?.emulationPaused != true else { return false }

        let keycode = event.keyCode
        let isRepeat = event.isARepeat
        let keyValue = unicodeKey(for: event)
        if ((currentModifiers & commandModifierMask) == 0) || isRepeat {
            // Leave non-command keys and repeats to normal event handling.
            return false
        }
        // Otherwise, manually do down, then up, for this key
        EmulatorCore.updateKey(
            imagePointer, keyCode: Int32(keycode),
            unicode: UInt32(keyValue), isUp: false)
        EmulatorCore.updateKey(
            imagePointer, keyCode: Int32(keycode),
            unicode: UInt32(keyValue), isUp: true)
        return true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    func unicodeKey(for event: NSEvent) -> UInt32 {
        var keyValue = UInt32(0)
        if let str = event.charactersIgnoringModifiers {
            let scalars = Array(str.unicodeScalars)
            if scalars.count == 1 {
                keyValue = UInt32(scalars[0])
            }
        }
        return keyValue
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 120 {
            if !event.isARepeat { session?.showSnapshots(nil) }
            return
        }
        if event.keyCode == 99 {
            if !event.isARepeat { saveScreenshot(nil) }
            return
        }
        guard session?.emulationPaused != true else { return }

        let keycode = event.keyCode
        let isRepeat = event.isARepeat
        let keyValue = unicodeKey(for: event)
        if isRepeat {
            // Command shortcuts can produce repeats without a matching key-down.
            return
        }
        EmulatorCore.updateKey(
            imagePointer, keyCode: Int32(keycode),
            unicode: UInt32(keyValue), isUp: false)
    }

    override func keyUp(with event: NSEvent) {
        // F2 and F3 belong to the host, never the emulated keyboard.
        if event.keyCode == 120 || event.keyCode == 99 { return }

        let keycode = event.keyCode
        let keyValue = unicodeKey(for: event)
        EmulatorCore.updateKey(
            imagePointer, keyCode: Int32(keycode),
            unicode: UInt32(keyValue), isUp: true)
    }

    override func flagsChanged(with event: NSEvent) {
        let flags =
            event.modifierFlags.rawValue
            & (commandModifierMask | controlModifierMask | shiftModifierMask | capsLockModifierMask
                | optionModifierMask)
        var modifierBits = UInt32(0)
        if (flags & shiftModifierMask) != 0 {
            modifierBits |= 1
        }
        if (flags & controlModifierMask) != 0 {
            modifierBits |= 2
        }
        if (flags & capsLockModifierMask) != 0 {
            modifierBits |= 4
        }
        if (flags & optionModifierMask) != 0 {
            modifierBits |= 0x40
        }
        if (flags & commandModifierMask) != 0 {
            modifierBits |= 0x80
        }
        EmulatorCore.updateModifiers(imagePointer, value: modifierBits, mask: UInt32(0xc7))
        currentModifiers = flags
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Require a separate click to focus the window before forwarding mouse input.
        return false
    }

    override func mouseMoved(with event: NSEvent) {
        updateMouse(with: event, buttonsState: 0, validButtons: 0)
    }

    override func mouseDragged(with event: NSEvent) {
        updateMouse(
            with: event, buttonsState: 0,
            validButtons: 0)
    }

    override func otherMouseDown(with event: NSEvent) {
        updateMouse(with: event, buttonsState: 2, validButtons: 2)
    }

    override func otherMouseUp(with event: NSEvent) {
        updateMouse(with: event, buttonsState: 0, validButtons: 2)
    }

    override func mouseEntered(with event: NSEvent) {
        print("mouse entered")
    }

    override func rightMouseUp(with event: NSEvent) {
        updateMouse(with: event, buttonsState: 0, validButtons: 4)
    }

    override func rightMouseDown(with event: NSEvent) {
        print("Right mouse down")
        updateMouse(with: event, buttonsState: 4, validButtons: 4)
    }

    override func mouseUp(with event: NSEvent) {
        updateMouse(with: event, buttonsState: 0, validButtons: 1)
    }

    override func mouseDown(with event: NSEvent) {
        updateMouse(with: event, buttonsState: 1, validButtons: 1)
    }

    func updateMouse(
        with event: NSEvent, buttonsState: Int,
        validButtons: Int
    ) {
        var warp = Int32(0)
        var viewWidth = 0
        var viewHeight = 0
        var x = Int32(0)
        var y = Int32(0)
        var deltaMode = Int(0)
        let hide = EmulatorCore.pointerVisibility(imagePointer, warp: &warp)
        if warp != pointerWarpState {
            mouseMovedSinceWarp = true
        }
        pointerWarpState = warp
        if pointerHiddenState != hide {
            setPointerHidden(hide)
        }
        pointerHiddenState = hide
        let location = event.locationInWindow
        if !usesDirectContextDrawing {
            // We're letting the Mac scale the window for us,
            //  so video_scale_mouse*() doesn't know the scale
            //  factor, so pass it in
            viewWidth = Int(bounds.size.width)
            viewHeight = Int(bounds.size.height)
        }

        let rawX = location.x
        // Convert AppKit’s bottom-origin coordinates to the emulator’s top origin.
        let rawY = bounds.size.height - 1 - location.y
        x = EmulatorCore.scaleMouseX(
            imagePointer, x: Int32(rawX),
            width: Int32(viewWidth))
        y = EmulatorCore.scaleMouseY(
            imagePointer, y: Int32(rawY),
            height: Int32(viewHeight))
        deltaMode = 0
        if pointerWarpState != 0 {
            deltaMode |= 0x1000  // x,y are deltas
            x = Int32(event.deltaX)
            y = Int32(event.deltaY)
        }

        let ret = EmulatorCore.updateMouse(
            imagePointer, x: x, y: y,
            buttons: Int32(buttonsState),
            validButtons: Int32(validButtons | deltaMode))
        if ret != 0 {
            mouseMovedSinceWarp = true
        }
        guard let win = window else {
            return  // No valid window
        }
        if mouseMovedSinceWarp {
            var rect1 = NSRect.zero

            // If warp, warp cursor to middle of window.  Moving
            //  the cursor requires absolute screen coordinates,
            //  where y=0 is the top of the screen.  We must convert
            //  window coords (where y=0 is the bottom of the win).
            mouseMovedSinceWarp = false
            let warpX = CGFloat(
                EmulatorCore.unscaleMouseX(
                    imagePointer,
                    x: Int32(EmulatorCore.defaultImageWidth / 2), width: Int32(viewWidth)))
            let warpY = CGFloat(
                EmulatorCore.unscaleMouseY(
                    imagePointer,
                    y: Int32(EmulatorCore.defaultImageHeight / 2), height: Int32(viewHeight)))
            let screenHeight = CGDisplayPixelsHigh(CGMainDisplayID())
            rect1.origin.x = CGFloat(warpX)
            rect1.origin.y = bounds.size.height - 1 - CGFloat(warpY)
            rect1.size.width = 1
            rect1.size.height = 0
            let screenRect = win.convertToScreen(rect1)
            let screenRectY = CGFloat(screenHeight) - screenRect.origin.y
            let cursorLocation = CGPoint(
                x: screenRect.origin.x,
                y: CGFloat(screenRectY))
            if warp != 0 {
                // Warp to middle of the window
                CGDisplayMoveCursorToPoint(
                    CGMainDisplayID(),
                    cursorLocation)
            }
        }
    }

    func setPointerHidden(_ hide: Int32) {
        if hide != 0 {
            CGDisplayHideCursor(CGMainDisplayID())
        } else {
            CGDisplayShowCursor(CGMainDisplayID())
        }
    }

    /// Recreates the owned bitmap context and its borrowed data pointers for the current image size.
    func initialize() {
        print("Initialize view called")
        // Get width,height from video.c to handle toggling status lines
        let width = Int(EmulatorCore.emulatedImageWidth(imagePointer))
        let height = Int(EmulatorCore.emulatedImageHeight(imagePointer))
        framebuffer = EmulatorFramebuffer(width: width, height: height)
        let viewWidth = Int(EmulatorCore.imageWidth(imagePointer))
        let viewHeight = Int(EmulatorCore.imageHeight(imagePointer))
        EmulatorCore.updateImageScale(
            imagePointer, width: Int32(viewWidth), height: Int32(viewHeight),
            force: true)
        if usesDirectContextDrawing {
            EmulatorCore.setAlphaMask(UInt32(0xff00_0000))
            // Set video.c alpha mask, since 0 means transparent
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Draw the current image buffer to the screen
        let context = NSGraphicsContext.current!.cgContext
        if !usesDirectContextDrawing {
            // Safe, simple drawing
            let image = framebuffer!.frame!
            context.setFillColor(NSColor.black.cgColor)
            context.fill(bounds)
            context.interpolationQuality = .none
            let ratio = min(bounds.width / CGFloat(image.width), bounds.height / CGFloat(image.height))
            let size = CGSize(width: CGFloat(image.width) * ratio, height: CGFloat(image.height) * ratio)
            let destination = CGRect(
                x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width,
                height: size.height)
            context.draw(image, in: destination)
        } else {
            EmulatorFramebuffer.drawDirect(imagePointer, in: context)
        }
    }

    /// Presents the captured frame immediately, including when restoring while paused.
    func showSnapshotPreview(at url: URL) {
        guard let framebuffer = framebuffer, let image = screenshots.preview(at: url)
        else { return }
        framebuffer.displayPreview(image)
        needsDisplay = true
    }

    /// Saves the current native-resolution game frame, without window chrome or overlays.
    /// Throws if no frame is available, PNG encoding fails, or the destination cannot be written.
    @discardableResult
    func saveScreenshot(in directory: URL) throws -> URL {
        return try screenshots.save(
            frame: framebuffer?.frame,
            gameName: PlayerManifest.displayName, in: directory)
    }

    @objc func saveScreenshot(_ sender: Any?) {
        if let event = NSApp.currentEvent, event.type == .keyDown, event.isARepeat { return }
        do {
            let pictures = try FileManager.default.url(
                for: .picturesDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true)
            let directory = pictures.appendingPathComponent("Apple II Player", isDirectory: true)
                .appendingPathComponent(
                    PlayerManifest.normalizedName(PlayerManifest.displayName), isDirectory: true)
            _ = try saveScreenshot(in: directory)
            screenshotSound?.play()
        } catch {
            let alert = NSAlert()
            let player = session
            player?.setDialogOpen(true, reason: "Screenshot Error")
            defer { player?.setDialogOpen(false, reason: "Screenshot Error") }
            alert.messageText = playerViewIntl.couldNotSaveScreenshot
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc func showEmulatorConfiguration(_: AnyObject) {
        // Send a complete F4 press to open the emulator configuration.
        EmulatorCore.updateKey(imagePointer, keyCode: Int32(0x76), unicode: 0, isUp: false)

        EmulatorCore.updateKey(imagePointer, keyCode: Int32(0x76), unicode: 0, isUp: true)
    }

    @objc func copyTextScreen(_: AnyObject) {
        if let str = EmulatorCore.textScreen() {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
                str,
                forType: NSPasteboard.PasteboardType.string)
        }
    }

    @objc func pasteText(_: AnyObject) {
        let general = NSPasteboard.general
        guard let str = general.string(forType: .string) else {
            print("Cannot paste, nothing in clipboard")
            return
        }
        for rawCharacter in str.utf8 {
            let c = UInt32(rawCharacter)
            let ret = EmulatorCore.pasteCharacter(c)
            if ret != 0 {
                print("Paste too large!")
                return
            }
        }
    }

    func updateDisplay() {
        let changed =
            usesDirectContextDrawing
            ? EmulatorCore.imageChanges(imagePointer) != 0
            : framebuffer?.update(from: imagePointer) == true
        // Core dirty rectangles use native pixels; the presentation invalidates its scaled bounds.
        if changed { setNeedsDisplay(bounds) }
    }
}
