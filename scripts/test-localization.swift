import Foundation

@main struct LocalizationTests {
    static func main() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let english = Bundle(path: root.appendingPathComponent("Resources/Localizations/en.lproj").path)!
        let builder = BuilderIntl(bundle: english)
        precondition(builder.chooseDisks == "Choose Disks…")
        precondition(builder.diskImagesSelected(count: 1) == "1 disk image selected")
        precondition(builder.diskImagesSelected(count: 2) == "2 disk images selected")
        precondition(SnapshotBrowserIntl(bundle: english).savedSnapshotCount(count: 1) == "1 saved snapshot")
        precondition(SnapshotBrowserIntl(bundle: english).savedSnapshotCount(count: 4) == "4 saved snapshots")
        precondition(PlayerIntl(bundle: english).pausedTitle(gameName: "Rastan", reason: "Controller disconnected") == "Rastan — Paused (Controller disconnected)")
        precondition(ControllerConfigurationIntl(bundle: english).deadZone(percent: 15) == "Dead zone: 15%")
        precondition(ROMSetupIntl(bundle: english).installedRom(model: "03", identifier: "ABC123") == "Installed ROM 03 — ABC123")
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let localized = temporary.appendingPathComponent("test.lproj")
        try FileManager.default.createDirectory(at: localized, withIntermediateDirectories: true)
        try "\"recoveryFailure\" = \"ERROR %2$@ | PATH %1$@\";".write(
            to: localized.appendingPathComponent("Snapshots.strings"), atomically: true, encoding: .utf8)
        let translated = SnapshotsIntl(bundle: Bundle(path: localized.path)!)
        let message = translated.recoveryFailure(recoveryPath: "/Games/100%.po", errorDescription: "Disk missing")
        precondition(message == "ERROR Disk missing | PATH /Games/100%.po")
        let noTranslations = Bundle(path: temporary.path)!
        precondition(BuilderIntl(bundle: noTranslations).chooseDisks == "Choose Disks…")
        precondition(BuilderIntl(bundle: noTranslations).diskImagesSelected(count: 1) == "1 disk image selected")
        for path in CommandLine.arguments.dropFirst() {
            let app = Bundle(path: path)!
            let tables = try FileManager.default.contentsOfDirectory(
                at: root.appendingPathComponent("Resources/Localizations/en.lproj"),
                includingPropertiesForKeys: nil)
            for table in tables {
                let packaged = app.resourceURL!.appendingPathComponent("en.lproj/" + table.lastPathComponent)
                precondition(try! Data(contentsOf: packaged) == Data(contentsOf: table), "Packaged resource differs: " + table.lastPathComponent)
            }
            precondition(app.object(forInfoDictionaryKey: "CFBundleDevelopmentRegion") as? String == "en")
            precondition(app.localizedString(forKey: "chooseDisks", value: nil, table: "Builder") == "Choose Disks…")
            precondition(BuilderIntl(bundle: app).diskImagesSelected(count: 1) == "1 disk image selected")
        }
        print("PASS English lookup, plurals, percent escaping, named/reordered placeholders and English fallback")
    }
}
