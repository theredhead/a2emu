import Cocoa

/// Coordinates an AppKit window with an image borrowed from the emulator core.
class EmulatorWindow {
    var window: NSWindow? = nil
    var view: MainView? = nil
    var imagePointer: EmulatorCore.Image! = nil
    var title: String = ""
    private weak var coordinator: PlayerWindowCoordinator?
    private weak var session: PlayerViewSession?
    var cachedImageHeight: Int = 0

    func setImage(
        _ imagePointer: EmulatorCore.Image!,
        title: String, coordinator: PlayerWindowCoordinator, session: PlayerViewSession
    ) {
        self.imagePointer = imagePointer
        self.title = title
        self.coordinator = coordinator
        self.session = session
    }

    func createWindow() {
        let windowX = Int(EmulatorCore.windowX(imagePointer))
        let windowY = Int(EmulatorCore.windowY(imagePointer))
        let width = Int(EmulatorCore.imageWidth(imagePointer))
        let height = Int(EmulatorCore.imageHeight(imagePointer))
        let windowRect = NSRect(
            x: windowX, y: windowY, width: width,
            height: height)
        var window: NSWindow!
        var view: MainView!
        let style: NSWindow.StyleMask = [
            .titled, .closable,
            .resizable, .miniaturizable,
        ]

        window = NSWindow(
            contentRect: windowRect,
            styleMask: style,
            backing: .buffered, defer: false)

        let viewRect = NSRect(
            x: 0, y: 0, width: windowRect.size.width,
            height: windowRect.size.height)
        print("About to init MainView")
        view = MainView(frame: viewRect)
        print("About to set imagePointer")
        view.imagePointer = imagePointer
        view.session = session
        print("About to call initialize")
        view.initialize()
        view.closed = false

        window.delegate = coordinator
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
        window.acceptsMouseMovedEvents = true
        window.title = title
        window.showsToolbarButton = false
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.makeFirstResponder(view)
        window.center()
        window.contentAspectRatio = NSSize(width: width, height: height)

        EmulatorCore.setImageActivity(imagePointer, active: Int32(1))
        EmulatorCore.updateImageScale(
            imagePointer, width: Int32(width), height: Int32(height),
            force: true)

        self.window = window
        self.view = view
        cachedImageHeight = height
        window.makeKey()
    }

    /// Synchronizes window visibility, size, and pixels with the emulator image.
    func update() {
        let newHeight = Int(EmulatorCore.emulatedImageHeight(imagePointer))
        let imageActive = EmulatorCore.imageActivity(imagePointer)
        if let view = view {
            if newHeight != cachedImageHeight {
                resizeWindow()
            }
            if imageActive == 0 && !view.closed {
                print("imageActive 0 on \(title), calling close")
                window!.orderOut(window)
                view.closed = true
            } else if imageActive != 0 && view.closed {
                print("Opening closed window \(title)")
                view.closed = false
                window!.orderFront(window)
                window!.makeKey()  // Move to front
            } else if imageActive != 0 {
                view.updateDisplay()
            }
            if (imageActive != 0) && !view.closed {
                if EmulatorCore.copyRequested() != 0 {
                    view.copyTextScreen(view)
                }
            }
        } else {
            if imageActive != 0 {
                print("Opening window \(title)")
                createWindow()
            }
        }
    }

    func resizeWindow() {
        let imageHeight = Int(EmulatorCore.emulatedImageHeight(imagePointer))
        let imageWidth = Int(EmulatorCore.emulatedImageWidth(imagePointer))
        let ratio = CGFloat(imageHeight) / CGFloat(imageWidth)

        let contentWidth = window!.contentView!.bounds.width
        cachedImageHeight = imageHeight
        window!.contentAspectRatio = NSSize(
            width: imageWidth,
            height: imageHeight)
        if !window!.styleMask.contains(.fullScreen), coordinator?.changingFullScreen != true {
            window!.setContentSize(NSSize(width: contentWidth, height: contentWidth * ratio))
            coordinator?.snapWindowToIntegerSize()
        }
        // Recreate the bitmap because enabling status lines changes the display height.
        view!.initialize()
        EmulatorCore.updateImageScale(
            imagePointer, width: Int32(window!.frame.width),
            height: Int32(window!.frame.height), force: false)
        EmulatorCore.updateWindowPosition(
            imagePointer, x: Int32(window!.frame.origin.x),
            y: Int32(window!.frame.origin.y))
    }

    func updateWindowSize(width: Int, height: Int) {
        EmulatorCore.updateImageScale(imagePointer, width: Int32(width), height: Int32(height), force: false)
    }
}
