// $KmKId: MainView.swift,v 1.42 2024-09-15 13:55:35+00 kentd Exp $

//	Copyright 2019-2024 by Kent Dickey
//	This code is covered by the GNU GPL v3
//	See the file COPYING.txt or https://www.gnu.org/licenses/
//

import AudioToolbox
import Cocoa
import CoreGraphics

/// Displays an emulator-owned image and forwards AppKit keyboard and mouse input.
class MainView: NSView {
    var bitmapContext: CGContext!
    var bitmapData: UnsafeMutableRawPointer!
    var rawData: UnsafeMutablePointer<UInt32>!
    var current_flags: UInt = 0
    var mouse_moved: Bool = false
    var mac_warp_pointer: Int32 = 0
    var mac_hide_pointer: Int32 = 0

    /// Borrowed from the C core; the emulator retains ownership.
    var kimage_ptr: UnsafeMutablePointer<Kimage>!
    var closed: Bool = false
    var pixels_per_line = 640
    var max_height = 600
    // Retain the sound until playback finishes; system resources can be absent on future macOS versions.
    private let screenshotSound = NSSound(
        contentsOfFile:
            "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif",
        byReference: true)

    let is_cmd = UInt(NSEvent.ModifierFlags.command.rawValue)
    let is_control = UInt(NSEvent.ModifierFlags.control.rawValue)
    let is_shift = NSEvent.ModifierFlags.shift.rawValue
    let is_capslock = NSEvent.ModifierFlags.capsLock.rawValue
    let is_option = NSEvent.ModifierFlags.option.rawValue

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func windowDidResize(_ notification: Notification) {
        print("DID RESIZE")
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 99 { return false }  // Leave F3 to the screenshot menu command or keyDown.
        guard (NSApp.delegate as? AppDelegate)?.emulationPaused != true else { return false }
        let keycode = event.keyCode
        let is_repeat = event.isARepeat
        let unicode_key = get_unicode_key_from_event(event)
        if ((current_flags & is_cmd) == 0) || is_repeat {
            // Leave non-command keys and repeats to normal event handling.
            return false
        }
        // Otherwise, manually do down, then up, for this key
        adb_physical_key_update(
            kimage_ptr, Int32(keycode),
            UInt32(unicode_key), 0)
        adb_physical_key_update(
            kimage_ptr, Int32(keycode),
            UInt32(unicode_key), 1)
        return true
    }

    override var acceptsFirstResponder: Bool {
        return true
    }

    func get_unicode_key_from_event(_ event: NSEvent) -> UInt32 {
        var unicode_key = UInt32(0)
        if let str = event.charactersIgnoringModifiers {
            let arr_chars = Array(str.unicodeScalars)
            if arr_chars.count == 1 {
                unicode_key = UInt32(arr_chars[0])
            }
        }
        return unicode_key
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 99 {
            if !event.isARepeat { do_screenshot(nil) }
            return
        }
        guard (NSApp.delegate as? AppDelegate)?.emulationPaused != true else { return }
        let keycode = event.keyCode
        let is_repeat = event.isARepeat
        let unicode_key = get_unicode_key_from_event(event)
        if is_repeat {
            // Command shortcuts can produce repeats without a matching key-down.
            return
        }
        adb_physical_key_update(
            kimage_ptr, Int32(keycode),
            UInt32(unicode_key), 0)
    }

    override func keyUp(with event: NSEvent) {
        if event.keyCode == 99 { return }  // F3 belongs to the host, never the emulated keyboard.
        let keycode = event.keyCode
        let unicode_key = get_unicode_key_from_event(event)
        adb_physical_key_update(
            kimage_ptr, Int32(keycode),
            UInt32(unicode_key), 1)
    }

    override func flagsChanged(with event: NSEvent) {
        let flags = event.modifierFlags.rawValue & (is_cmd | is_control | is_shift | is_capslock | is_option)
        var c025_val = UInt32(0)
        if (flags & is_shift) != 0 {
            c025_val |= 1
        }
        if (flags & is_control) != 0 {
            c025_val |= 2
        }
        if (flags & is_capslock) != 0 {
            c025_val |= 4
        }
        if (flags & is_option) != 0 {
            c025_val |= 0x40
        }
        if (flags & is_cmd) != 0 {
            c025_val |= 0x80
        }
        adb_update_c025_mask(kimage_ptr, c025_val, UInt32(0xc7))
        current_flags = flags
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        // Require a separate click to focus the window before forwarding mouse input.
        return false
    }

    override func mouseMoved(with event: NSEvent) {
        mac_update_mouse(event: event, buttons_state: 0, buttons_valid: 0)
    }

    override func mouseDragged(with event: NSEvent) {
        mac_update_mouse(
            event: event, buttons_state: 0,
            buttons_valid: 0)
    }

    override func otherMouseDown(with event: NSEvent) {
        mac_update_mouse(event: event, buttons_state: 2, buttons_valid: 2)
    }

    override func otherMouseUp(with event: NSEvent) {
        mac_update_mouse(event: event, buttons_state: 0, buttons_valid: 2)
    }

    override func mouseEntered(with event: NSEvent) {
        print("mouse entered")
    }

    override func rightMouseUp(with event: NSEvent) {
        mac_update_mouse(event: event, buttons_state: 0, buttons_valid: 4)
    }

    override func rightMouseDown(with event: NSEvent) {
        print("Right mouse down")
        mac_update_mouse(event: event, buttons_state: 4, buttons_valid: 4)
    }

    override func mouseUp(with event: NSEvent) {
        mac_update_mouse(event: event, buttons_state: 0, buttons_valid: 1)
    }

    override func mouseDown(with event: NSEvent) {
        mac_update_mouse(event: event, buttons_state: 1, buttons_valid: 1)
    }

    func mac_update_mouse(
        event: NSEvent, buttons_state: Int,
        buttons_valid: Int
    ) {
        var warp = Int32(0)
        var x_width = 0
        var y_height = 0
        var x = Int32(0)
        var y = Int32(0)
        var do_delta = Int(0)
        let hide = adb_get_hide_warp_info(kimage_ptr, &warp)
        if warp != mac_warp_pointer {
            mouse_moved = true
        }
        mac_warp_pointer = warp
        if mac_hide_pointer != hide {
            mac_hide_pointer(hide: hide)
        }
        mac_hide_pointer = hide
        let location = event.locationInWindow
        if !Context_draw {
            // We're letting the Mac scale the window for us,
            //  so video_scale_mouse*() doesn't know the scale
            //  factor, so pass it in
            x_width = Int(bounds.size.width)
            y_height = Int(bounds.size.height)
        }

        let raw_x = location.x
        // Convert AppKit’s bottom-origin coordinates to the emulator’s top origin.
        let raw_y = bounds.size.height - 1 - location.y
        x = video_scale_mouse_x(
            kimage_ptr, Int32(raw_x),
            Int32(x_width))
        y = video_scale_mouse_y(
            kimage_ptr, Int32(raw_y),
            Int32(y_height))
        do_delta = 0
        if mac_warp_pointer != 0 {
            do_delta |= 0x1000  // x,y are deltas
            x = Int32(event.deltaX)
            y = Int32(event.deltaY)
        }

        let ret = adb_update_mouse(
            kimage_ptr, x, y,
            Int32(buttons_state),
            Int32(buttons_valid | do_delta))
        if ret != 0 {
            mouse_moved = true
        }
        guard let win = window else {
            return  // No valid window
        }
        if mouse_moved {
            var rect1 = NSRect.zero

            // If warp, warp cursor to middle of window.  Moving
            //  the cursor requires absolute screen coordinates,
            //  where y=0 is the top of the screen.  We must convert
            //  window coords (where y=0 is the bottom of the win).
            mouse_moved = false
            let warp_x = CGFloat(
                video_unscale_mouse_x(
                    kimage_ptr,
                    Int32(A2_WINDOW_WIDTH / 2), Int32(x_width)))
            let warp_y = CGFloat(
                video_unscale_mouse_y(
                    kimage_ptr,
                    Int32(A2_WINDOW_HEIGHT / 2), Int32(y_height)))
            let scr_height = CGDisplayPixelsHigh(CGMainDisplayID())
            rect1.origin.x = CGFloat(warp_x)
            rect1.origin.y = bounds.size.height - 1 - CGFloat(warp_y)
            rect1.size.width = 1
            rect1.size.height = 0
            let screen_rect = win.convertToScreen(rect1)
            let screen_rect_y = CGFloat(scr_height) - screen_rect.origin.y
            let cg_loc = CGPoint(
                x: screen_rect.origin.x,
                y: CGFloat(screen_rect_y))
            if warp != 0 {
                // Warp to middle of the window
                CGDisplayMoveCursorToPoint(
                    CGMainDisplayID(),
                    cg_loc)
            }
        }
    }

    func mac_hide_pointer(hide: Int32) {
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
        let width = Int(video_get_a2_width(kimage_ptr))
        let height = Int(video_get_a2_height(kimage_ptr))
        pixels_per_line = width
        max_height = height

        let color_space = CGDisplayCopyColorSpace(CGMainDisplayID())
        bitmapContext = CGContext(
            data: nil, width: width,
            height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: color_space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)

        bitmapData = bitmapContext.data!
        // Initialize the bitmap to black before the first emulator update.
        bitmapData.initializeMemory(
            as: UInt32.self, repeating: 0,
            count: height * width)
        rawData = bitmapData.bindMemory(
            to: UInt32.self,
            capacity: height * width)
        let x_width = Int(video_get_x_width(kimage_ptr))
        let x_height = Int(video_get_x_height(kimage_ptr))
        video_update_scale(
            kimage_ptr, Int32(x_width), Int32(x_height),
            Int32(1))
        if Context_draw {
            video_set_alpha_mask(UInt32(0xff00_0000))
            // Set video.c alpha mask, since 0 means transparent
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        var rect: Change_rect
        // Draw the current image buffer to the screen
        let context = NSGraphicsContext.current!.cgContext
        if !Context_draw {
            // Safe, simple drawing
            let image = bitmapContext.makeImage()!
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
            // Unsafe, more direct drawing by peeking into
            // NSGraphicsContext.current.data
            if let data = context.data {
                rect = Change_rect(
                    x: 0, y: 0,
                    width: Int32(context.width),
                    height: Int32(context.height))
                video_update_scale(
                    kimage_ptr,
                    Int32(context.width),
                    Int32(context.height), Int32(0))
                video_out_data_scaled(
                    data, kimage_ptr,
                    Int32(context.bytesPerRow / 4), &rect)
                video_out_done(kimage_ptr)
                print("Did out_data_scaled, rect:\(rect)")
            }
        }
    }

    /// Saves the current native-resolution game frame, without window chrome or overlays.
    /// Throws if no frame is available, PNG encoding fails, or the destination cannot be written.
    @discardableResult
    func saveScreenshot(in directory: URL) throws -> URL {
        guard let image = bitmapContext?.makeImage(),
            let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        else {
            throw PlayerManifest.failure("No game frame is available to capture yet.")
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss.SSS"
        let name =
            PlayerManifest.normalizedName(PlayerManifest.displayName)
            + " " + formatter.string(from: Date()) + " " + UUID().uuidString.prefix(6) + ".png"
        let destination = directory.appendingPathComponent(name)
        try png.write(to: destination, options: .atomic)
        return destination
    }

    @objc func do_screenshot(_ sender: Any?) {
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
            alert.messageText = "Could not save screenshot"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    @objc func do_config(_: AnyObject) {
        // Send a complete F4 press to open the emulator configuration.
        adb_physical_key_update(kimage_ptr, Int32(0x76), 0, 0)

        adb_physical_key_update(kimage_ptr, Int32(0x76), 0, 1)
    }

    @objc func do_copy_text(_: AnyObject) {
        if let cstr = cfg_text_screen_str() {
            let str = String(cString: cstr)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(
                str,
                forType: NSPasteboard.PasteboardType.string)
        }
    }

    @objc func do_paste(_: AnyObject) {
        let general = NSPasteboard.general
        guard let str = general.string(forType: .string) else {
            print("Cannot paste, nothing in clipboard")
            return
        }
        for raw_c in str.utf8 {
            let c = UInt32(raw_c)
            let ret = adb_paste_add_buf(c)
            if ret != 0 {
                print("Paste too large!")
                return
            }
        }
    }

    func mac_update_display() {
        var valid: Int32
        var rect: Change_rect
        var dirty_rect = NSRect.zero

        if Context_draw {
            // We just need to know if there are any changes,
            //  don't actually do the copies now
            valid = video_out_query(kimage_ptr)
            if valid != 0 {
                self.setNeedsDisplay(bounds)
                print("Needs display")
            }
            return
        }
        // Otherwise, update rawData in our Bitmap now
        rect = Change_rect(x: 0, y: 0, width: 0, height: 0)
        for i in 0..<MAX_CHANGE_RECTS {
            valid = video_out_data(
                rawData, kimage_ptr,
                Int32(pixels_per_line), &rect, Int32(i))
            if valid == 0 {
                break
            }
            dirty_rect.origin.x = CGFloat(rect.x)
            dirty_rect.origin.y = bounds.size.height - CGFloat(rect.y) - CGFloat(rect.height)
            dirty_rect.size.width = CGFloat(rect.width)
            dirty_rect.size.height = CGFloat(rect.height)

            // Redraw the full view: emulator dirty rectangles are not transformed to view coordinates.
            self.setNeedsDisplay(bounds)
        }
    }
}
