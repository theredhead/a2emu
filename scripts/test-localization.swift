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
        let dutch = Bundle(path: root.appendingPathComponent("Resources/Localizations/nl.lproj").path)!
        let dutchBuilder = BuilderIntl(bundle: dutch)
        precondition(CommonIntl(bundle: dutch).cancel == "Annuleer")
        precondition(dutchBuilder.chooseDisks == "Kies schijven…")
        precondition(dutchBuilder.diskImagesSelected(count: 0) == "0 schijfkopieën geselecteerd")
        precondition(dutchBuilder.diskImagesSelected(count: 1) == "1 schijfkopie geselecteerd")
        precondition(dutchBuilder.diskImagesSelected(count: 2) == "2 schijfkopieën geselecteerd")
        precondition(SnapshotBrowserIntl(bundle: dutch).savedSnapshotCount(count: 1) == "1 bewaarde momentopname")
        precondition(SnapshotBrowserIntl(bundle: dutch).savedSnapshotCount(count: 3) == "3 bewaarde momentopnamen")
        precondition(PlayerMenuIntl(bundle: dutch).quit(appName: "Rastan") == "Stop Rastan")
        precondition(PlayerIntl(bundle: dutch).pausedTitle(gameName: "Rastan", reason: "Controller disconnected") == "Rastan — Gepauzeerd (Controller niet verbonden)")
        precondition(ControllerConfigurationIntl(bundle: dutch).deadZone(percent: 8) == "Dode zone: 8%")
        print("PASS Dutch labels, plural forms, named arguments, unchanged game names and stable pause identities")
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
            for language in ["en", "nl"] {
                for table in tables {
                    let source = root.appendingPathComponent("Resources/Localizations/\(language).lproj/" + table.lastPathComponent)
                    let packaged = app.resourceURL!.appendingPathComponent("\(language).lproj/" + table.lastPathComponent)
                    precondition(try! Data(contentsOf: packaged) == Data(contentsOf: source), "Packaged resource differs: " + table.lastPathComponent)
                }
            }
            precondition(app.object(forInfoDictionaryKey: "CFBundleDevelopmentRegion") as? String == "en")
            precondition(app.localizations.contains("en") && app.localizations.contains("nl"))
            let prefersDutch = app.preferredLocalizations.first == "nl"
            precondition(app.localizedString(forKey: "chooseDisks", value: nil, table: "Builder") == (prefersDutch ? "Kies schijven…" : "Choose Disks…"))
            precondition(BuilderIntl(bundle: app).diskImagesSelected(count: 1) == (prefersDutch ? "1 schijfkopie geselecteerd" : "1 disk image selected"))
        }
        print("PASS English lookup, plurals, percent escaping, named/reordered placeholders and English fallback")
    }
}
