import Cocoa

private let commonIntl = CommonIntl()
private let romSetupIntl = ROMSetupIntl()

/// Presents firmware choices and modal progress; validated storage and network transfer are separate adapters.
enum ROMSetup {
    static func choose(directory: URL) -> URL? {
        while true {
            let alert = NSAlert()
            alert.messageText = romSetupIntl.setUpYourAppleIigsRom
            alert.informativeText =
                romSetupIntl.noAppleIigsRomIsBundled
            alert.addButton(withTitle: romSetupIntl.useSelectedRom)
            alert.addButton(withTitle: commonIntl.browse)
            alert.addButton(withTitle: commonIntl.cancel)
            let choices = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 330, height: 28))
            let cached =
                ((try? FileManager.default.contentsOfDirectory(
                    at: ROMLibrary.sharedDirectory(), includingPropertiesForKeys: nil)) ?? []).filter {
                    $0.pathExtension == "rom" && (try? ROMLibrary.normalized(Data(contentsOf: $0))) != nil
                }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            choices.addItems(withTitles: [romSetupIntl.recommendedROM, romSetupIntl.rom01])
            for url in cached {
                let size = (try? Data(contentsOf: url).count) ?? 0
                choices.addItem(
                    withTitle:
                        romSetupIntl.installedRom(
                            model: size == 262144 ? "03" : "01",
                            identifier: String(url.deletingPathExtension().lastPathComponent.prefix(8)))
                )
            }
            choices.target = nil
            alert.accessoryView = choices
            let response = alert.runModal()
            if response == .alertThirdButtonReturn {
                return nil
            }
            do {
                if response == .alertSecondButtonReturn {
                    let panel = NSOpenPanel()
                    panel.title = romSetupIntl.chooseAnAppleIigsRom
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    guard panel.runModal() == .OK, let url = panel.url else {
                        continue
                    }
                    return try ROMLibrary.install(Data(contentsOf: url), directory: directory)
                }
                if choices.indexOfSelectedItem >= 2 {
                    return try ROMLibrary.select(
                        cached[choices.indexOfSelectedItem - 2], directory: directory)
                }

                let parts: [(String, String)] =
                    choices.indexOfSelectedItem == 0
                    ? [
                        (
                            "Apple IIGS ROM 3 Banks FC-FD - 341-0728 (new).bin",
                            "b327c945a15a11b4a54ca1fb30f5974dc10f6322e280579e1cce51f775cfa588"
                        ),
                        (
                            "Apple IIGS ROM 3 Banks FF-FE - 341-0748 (new).bin",
                            "31947bb32cd6c564be93fd251e0900f45a9561874bc00307d4978c3db08c9a66"
                        ),
                    ]
                    : [
                        (
                            "Apple IIGS ROM 01 - 342-0077-B.bin",
                            "eeacf455cc642f9e7e36353ecf67eea65b4a9d725606400f50a0987006eed5f3"
                        )
                    ]
                guard let bytes = try download(parts) else {
                    continue
                }
                return try ROMLibrary.install(bytes, directory: directory)
            } catch {
                let failure = NSAlert()
                failure.messageText = romSetupIntl.couldNotInstallRom
                failure.informativeText = error.localizedDescription
                failure.runModal()
            }
        }
    }

    static func download(_ parts: [(String, String)]) throws -> Data? {
        let progress = NSAlert()
        progress.messageText = romSetupIntl.downloadingRom
        progress.informativeText = romSetupIntl.downloadVerificationHint
        progress.addButton(withTitle: commonIntl.cancel)
        let indicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 330, height: 16))
        indicator.style = .bar
        indicator.isIndeterminate = true
        indicator.startAnimation(nil)
        progress.accessoryView = indicator
        let transfer = ROMDownload()
        var outcome: Result<Data, Error>?
        transfer.start(parts) { result in
            outcome = result
            NSApp.abortModal()
        }
        _ = progress.runModal()
        transfer.cancel()
        return try outcome?.get()
    }
}
