import CryptoKit
import Foundation

/// Supplies deterministic HTTP results so transfer ownership, validation and cancellation need no network.
final class FirmwareFixtureProtocol: URLProtocol {
    static var payload = Data([1, 2, 3])

    override class func canInit(with request: URLRequest) -> Bool { return true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { return request }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.payload)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@main struct ArchitectureChecks {
    static func main() throws {
        var pause = EmulationPause()
        pause.setManual(true, reason: "Controller disconnected")
        pause.setDialog(true, reason: "Controls")
        pause.setDialog(true, reason: "Snapshots")
        pause.setDialog(false, reason: "Controls")
        precondition(pause.isPaused && !pause.canToggleManualPause)
        pause.setDialog(false, reason: "Snapshots")
        precondition(pause.isPaused && pause.reason == "Controller disconnected")
        pause.setManual(false, reason: nil)
        precondition(!pause.isPaused && pause.canToggleManualPause)
        print("PASS independent pause ownership without AppKit or an emulator")

        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("a2-boundaries-" + UUID().uuidString)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: root) }

        let resources = root.appendingPathComponent("Resources")
        let base = root.appendingPathComponent("Support")
        try manager.createDirectory(at: resources, withIntermediateDirectories: true)
        let disk = resources.appendingPathComponent("Game.po")
        try Data([1, 2, 3]).write(to: disk)
        var manifest = try PlayerManifest.make(disks: ["Game.po"], slot: 6, initialSpeed: .twoPointEightMHz)
        manifest.configurationRevision = "first"
        try JSONEncoder().encode(manifest).write(to: resources.appendingPathComponent("Player.json"))
        let legacy = base.appendingPathComponent("nl.theredhead.a2emu-player.legacy")
        try manager.createDirectory(at: legacy, withIntermediateDirectories: true)
        try Data([9]).write(to: legacy.appendingPathComponent("Game.po"))
        let storage = PlayerStorage(supportRoot: base)
        let opened = try storage.open(
            resource: resources,
            identifier: "nl.theredhead.applejuicer.juicebox.legacy", previewDirectory: nil)
        precondition(opened.directory.path == legacy.path)
        precondition(try! Data(contentsOf: opened.directory.appendingPathComponent("Game.po")) == Data([9]))
        let preview = root.appendingPathComponent("Preview")
        let previewFiles = try storage.open(
            resource: resources,
            identifier: "nl.theredhead.applejuicer.juicebox.legacy", previewDirectory: preview)
        precondition(previewFiles.directory == preview.appendingPathComponent("Support", isDirectory: true))
        precondition(
            try! Data(contentsOf: previewFiles.directory.appendingPathComponent("Game.po"))
                == Data([1, 2, 3]))
        print("PASS injected support roots, legacy saved-data identity and disposable-preview isolation")

        let configuration = PlayerConfigurationStore()
        let rom = root.appendingPathComponent("Firmware.rom")
        let config = try configuration.prepare(manifest: manifest, rom: rom, directory: opened.directory)
        var text = try String(contentsOf: config, encoding: .utf8)
        text = text.replacingOccurrences(
            of: "g_limit_speed = \(manifest.initialSpeed!.rawValue)", with: "g_limit_speed = 9")
        text += "custom_setting = retained\n"
        try text.write(to: config, atomically: true, encoding: .utf8)
        _ = try configuration.prepare(manifest: manifest, rom: rom, directory: opened.directory)
        precondition(try! String(contentsOf: config, encoding: .utf8).contains("g_limit_speed = 9"))
        manifest.configurationRevision = "second"
        _ = try configuration.prepare(manifest: manifest, rom: rom, directory: opened.directory)
        text = try String(contentsOf: config, encoding: .utf8)
        precondition(
            text.contains("g_limit_speed = \(manifest.initialSpeed!.rawValue)")
                && text.contains("custom_setting = retained"))
        precondition(
            configuration.mounts(manifest: manifest, directory: opened.directory)[
                DriveAddress(slot: 6, drive: 0)] == 0)
        print("PASS export-default revision persistence, preserved user settings and drive-path decoding")

        let settings = PlayerBuildConfiguration(
            name: "Boundary Preview", disks: [disk], bootSlot: 6,
            icon: nil, mounts: [DiskMount(diskIndex: 0, address: DriveAddress(slot: 6, drive: 0))],
            diskNames: ["Game"], drives: [DriveAddress(slot: 6, drive: 0)], speed: .twoPointEightMHz,
            fullScreen: false, startupSnapshot: nil, expansionMemoryKB: 8192)
        var previewDirectory: URL?
        let builds = PlayerBuildService(
            template: URL(fileURLWithPath: "build/JuiceBox.app"),
            launch: { app, directory in
                previewDirectory = directory
                precondition(manager.fileExists(atPath: app.path))
                throw NSError(domain: "LaunchFixture", code: 1)
            })
        do {
            try builds.preview(settings)
            preconditionFailure("Launch failure must propagate")
        } catch {}
        precondition(previewDirectory != nil && !manager.fileExists(atPath: previewDirectory!.path))
        precondition(try! Data(contentsOf: disk) == Data([1, 2, 3]))
        print("PASS preview-launch failure cleans exported files without changing original media")

        let configurationFixture = URLSessionConfiguration.ephemeral
        configurationFixture.protocolClasses = [FirmwareFixtureProtocol.self]
        let hash = SHA256.hash(data: FirmwareFixtureProtocol.payload).map { String(format: "%02x", $0) }
            .joined()

        func transfer(_ expected: String) -> Result<Data, Error>? {
            let download = ROMDownload(configuration: configurationFixture)
            var result: Result<Data, Error>?
            download.start([("fixture.rom", expected)]) { result = $0 }

            let deadline = Date().addingTimeInterval(5)
            while result == nil && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.01))
            }
            download.cancel()
            return result
        }
        guard case .success(let bytes)? = transfer(hash) else {
            preconditionFailure("Verified bytes must succeed")
        }
        precondition(bytes == FirmwareFixtureProtocol.payload)
        guard case .failure? = transfer("incorrect") else {
            preconditionFailure("Unverified firmware must fail")
        }

        let cancelled = ROMDownload(configuration: configurationFixture)
        var delivered = false
        cancelled.start([("fixture.rom", hash)]) { _ in delivered = true }
        cancelled.cancel()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        precondition(!delivered)
        print("PASS injected firmware transport, checksum failures and cancellation ownership")
    }
}
