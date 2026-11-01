import Foundation

/// A validated editable player read from its bundle. Reading metadata performs no UI or session mutation.
struct BuilderPlayerDocument {
    let url: URL
    let resources: URL
    let manifest: PlayerManifest
    let name: String
    let icon: Data?

    var disks: [URL] { return manifest.diskFiles.map { resources.appendingPathComponent($0) } }

    var snapshot: URL? {
        return manifest.startupSnapshot == true ? resources.appendingPathComponent("Startup.a2snapshot") : nil
    }

    init(url: URL) throws {
        self.url = url
        self.resources = url.appendingPathComponent("Contents/Resources")
        self.manifest = try PlayerExporter.read(app: url)
        let info =
            try PropertyListSerialization.propertyList(
                from: Data(contentsOf: url.appendingPathComponent("Contents/Info.plist")), format: nil)
            as? [String: Any]
        self.name =
            info?["CFBundleDisplayName"] as? String ?? info?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        self.icon = try? Data(contentsOf: resources.appendingPathComponent("PlayerIcon.png"))
    }
}
