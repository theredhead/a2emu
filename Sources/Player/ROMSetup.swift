import Cocoa
import CryptoKit

/// Installs validated firmware in a shared library and records each player’s selection.
struct ROMSetup {
    static let mirror =
        "https://mirrors.apple2.org.za/Apple%20II%20Documentation%20Project/Computers/Apple%20II/Apple%20IIGS/ROM%20Images/"
    static let filename = "Installed.rom"

    static func error(_ message: String) -> NSError {
        NSError(domain: "ROMSetup", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    /// Returns complete ROM 01/03 bytes in emulator bank order, or throws for unrecognized data.
    static func normalized(_ data: Data) throws -> Data {
        guard data.count == 131072 || data.count == 262144 else {
            throw error(
                "Choose a complete 128 KB ROM 01 or 256 KB ROM 03 image. Individual ROM chips and ZIP files are not complete ROM images."
            )
        }

        let bankCount = data.count / 65536
        let banks = (0..<bankCount).map { data.subdata(in: ($0 * 65536)..<(($0 + 1) * 65536)) }

        func isLastBank(_ b: Data) -> Bool {
            b[0xfffc] == 0x62 && b[0xfffd] == 0xfa && b[0xfded] == 0x6c
        }
        if isLastBank(banks[bankCount - 1]) {
            return data
        }
        // Some chip dumps list banks in reverse order.
        if isLastBank(banks[0]) {
            return banks.reversed().reduce(Data(), +)
        }
        throw error(
            "This image does not contain a recognized Apple IIgs reset vector. Please choose a different ROM."
        )
    }

    static let selectionFilename = "Selected-ROM.txt"

    static func sharedDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = base.appendingPathComponent("nl.theredhead.a2emu.player/ROMs", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// Returns the recorded shared ROM only if its filename and contents are valid.
    static func selected(in directory: URL) -> URL? {
        guard let shared = try? sharedDirectory(),
            let name = try? String(
                contentsOf: directory.appendingPathComponent(selectionFilename), encoding: .utf8),
            name == URL(fileURLWithPath: name).lastPathComponent, name.hasSuffix(".rom")
        else {
            return nil
        }

        let url = shared.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url), (try? normalized(data)) != nil else {
            return nil
        }
        return url
    }

    static func select(_ url: URL, directory: URL) throws -> URL {
        try url.lastPathComponent.write(
            to: directory.appendingPathComponent(selectionFilename), atomically: true, encoding: .utf8)
        return url
    }

    /// Resolves this player’s selection, adopts legacy firmware, or selects a valid shared ROM.
    /// Returns nil if none is available; throws if library access or selection persistence fails.
    static func existing(directory: URL) throws -> URL? {
        if let selected = selected(in: directory) {
            return selected
        }
        // Preserve an existing player's ROM choice when adopting the shared library.
        let legacy = directory.appendingPathComponent(filename)
        if let data = try? Data(contentsOf: legacy), (try? normalized(data)) != nil {
            return try install(data, directory: directory)
        }

        let shared = try sharedDirectory()
        if let installed = selected(in: shared) {
            return try select(installed, directory: directory)
        }

        let candidates = try FileManager.default.contentsOfDirectory(
            at: shared, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "rom" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        let valid = candidates.filter { url in
            guard let data = try? Data(contentsOf: url) else {
                return false
            }
            return (try? normalized(data)) != nil
        }
        if let installed = valid.first(where: { (try? Data(contentsOf: $0).count) == 262144 }) ?? valid.first
        {
            return try select(installed, directory: directory)
        }
        return nil
    }

    /// Normalizes and stores firmware by content hash, then selects it globally and for this player.
    static func install(_ data: Data, directory: URL) throws -> URL {
        let bytes = try normalized(data)
        let shared = try sharedDirectory()
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        let url = shared.appendingPathComponent(digest + ".rom")
        try bytes.write(to: url, options: .atomic)
        _ = try select(url, directory: shared)
        return try select(url, directory: directory)
    }

    static func choose(directory: URL) -> URL? {
        while true {
            let alert = NSAlert()
            alert.messageText = "Set up your Apple IIgs ROM"
            alert.informativeText =
                "No Apple IIgs ROM is bundled with this app. Choose a ROM to download, or browse for your own file. Installed ROMs are shared with your other a2emu players, so you only need to install them once. Each player keeps its own ROM choice. Changing this player’s ROM restarts the emulator."
            alert.addButton(withTitle: "Use Selected ROM")
            alert.addButton(withTitle: "Browse…")
            alert.addButton(withTitle: "Cancel")
            let choices = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 330, height: 28))
            let cached =
                ((try? FileManager.default.contentsOfDirectory(
                    at: sharedDirectory(), includingPropertiesForKeys: nil)) ?? []).filter {
                    $0.pathExtension == "rom" && (try? normalized(Data(contentsOf: $0))) != nil
                }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            choices.addItems(withTitles: ["ROM 03 (recommended)", "ROM 01"])
            for url in cached {
                let size = (try? Data(contentsOf: url).count) ?? 0
                choices.addItem(
                    withTitle:
                        "Installed ROM \(size == 262144 ? "03" : "01") — \(url.deletingPathExtension().lastPathComponent.prefix(8))"
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
                    panel.title = "Choose an Apple IIgs ROM"
                    panel.canChooseDirectories = false
                    panel.allowsMultipleSelection = false
                    guard panel.runModal() == .OK, let url = panel.url else {
                        continue
                    }
                    return try install(Data(contentsOf: url), directory: directory)
                }
                if choices.indexOfSelectedItem >= 2 {
                    return try select(cached[choices.indexOfSelectedItem - 2], directory: directory)
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
                return try install(bytes, directory: directory)
            } catch {
                let failure = NSAlert()
                failure.messageText = "Could not install ROM"
                failure.informativeText = error.localizedDescription
                failure.runModal()
            }
        }
    }

    /// Downloads and verifies each part while showing modal progress; call on the main thread.
    /// Returns nil on cancellation and throws on network or checksum failure.
    static func download(_ parts: [(String, String)]) throws -> Data? {
        let progress = NSAlert()
        progress.messageText = "Downloading ROM…"
        progress.informativeText = "Downloading from mirrors.apple2.org.za and verifying the image."
        progress.addButton(withTitle: "Cancel")
        let indicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 330, height: 16))
        indicator.style = .bar
        indicator.isIndeterminate = true
        indicator.startAnimation(nil)
        progress.accessoryView = indicator
        let session = URLSession(configuration: .ephemeral)
        var outcome: Result<Data, Error>?
        var cancelled = false
        var collected = Data()

        func next(_ index: Int) {
            if index == parts.count {
                outcome = .success(collected)
                NSApp.abortModal()
                return
            }

            let part = parts[index]
            var request = URLRequest(
                url: URL(
                    string: mirror + part.0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!)!)
            request.timeoutInterval = 30
            let task = session.dataTask(with: request) { data, response, failure in
                DispatchQueue.main.async {
                    guard !cancelled else {
                        return
                    }
                    if let failure = failure {
                        outcome = .failure(failure)
                    } else if let data = data, let response = response as? HTTPURLResponse,
                        response.statusCode == 200,
                        SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == part.1
                    {
                        collected.append(data)
                        next(index + 1)
                        return
                    } else {
                        outcome = .failure(
                            error("The download could not be verified. Try again or browse for your own ROM.")
                        )
                    }
                    NSApp.abortModal()
                }
            }
            task.resume()
        }
        DispatchQueue.main.async { next(0) }
        _ = progress.runModal()
        cancelled = true
        // Invalidate the dedicated session to cancel any in-flight request.
        session.invalidateAndCancel()
        return try outcome?.get()
    }
}
