import Cocoa
import WebKit

@main struct IconClickTest {
    static func main() {
        let app = NSApplication.shared
        let image = NSImage(size: NSSize(width: 600, height: 300))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 600, height: 300).fill()
        image.unlockFocus()
        let cancelled = IconPicker()
        var cancelledCrop = false
        cancelled.cropClosed = { cancelledCrop = !$0 }
        cancelled.showCrop(image: image) { _ in preconditionFailure("Closing must not apply a crop") }
        cancelled.window.close()
        precondition(cancelledCrop)
        let accepted = IconPicker()
        var croppedData: Data?
        var didAccept = false
        accepted.cropClosed = { didAccept = $0 }
        accepted.showCrop(image: image) { croppedData = $0 }
        accepted.crop.offset = CGPoint(x: 40, y: 0)
        accepted.zoomSlider.doubleValue = 2
        accepted.zoomChanged(accepted.zoomSlider)
        accepted.useCrop(nil)
        precondition(didAccept)
        let cropped = NSBitmapImageRep(data: croppedData!)!
        precondition(cropped.pixelsWide == 1024 && cropped.pixelsHigh == 1024)
        print("PASS non-square image crop, zoom, confirmation and cancellation without search")
        let picker = IconPicker()
        picker.show(searchName: "Rastan") { _ in }
        precondition(picker.query.stringValue == "Apple 2gs game Rastan")
        picker.searchBrowser.stopLoading()
        picker.searchBrowser.navigationDelegate = nil
        precondition(picker.query.cell?.sendsActionOnEndEditing == false)
        let data = try! Data(contentsOf: URL(fileURLWithPath: "Assets/PlayerIcon.png"))
        let url = "data:image/png;base64," + data.base64EncodedString()
        func waitForGrid(_ attempt: Int) {
            guard attempt < 100 else { fatalError("Grid did not finish loading") }
            if !picker.gridReady {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { waitForGrid(attempt + 1) }
                return
            }
            picker.pendingResults = [url]
            picker.updateResults()
            picker.browser.evaluateJavaScript(
                "window.firstResult = document.querySelector('button'); firstResult.click();"
            ) { _, error in
                precondition(error == nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    precondition(picker.crop.image != nil, "A single click must select the image")
                    picker.pendingResults = [url, url + "#second"]
                    picker.updateResults()
                    picker.browser.evaluateJavaScript(
                        "document.querySelectorAll('button').length === 2 && document.querySelector('button') === window.firstResult"
                    ) { result, error in
                        precondition(
                            error == nil && (result as? Bool) == true,
                            "Results must append without rebuilding existing buttons")
                        print(
                            "PASS search field focus behavior, single-click selection, stable results and deduplication"
                        )
                        picker.window.close()
                        exit(0)
                    }
                }
            }
        }
        waitForGrid(0)
        app.run()
    }
}
