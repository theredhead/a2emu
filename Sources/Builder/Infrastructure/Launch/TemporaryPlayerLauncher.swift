import Foundation

/// Launches a signed preview process and removes its containing workspace after termination.
/// The child also owns cleanup on normal exit, allowing the builder to quit before the preview.
enum TemporaryPlayerLauncher {
    static func launch(app: URL, cleanupDirectory: URL) throws {
        let process = Process()
        process.executableURL = Bundle(url: app)!.executableURL!
        process.arguments = ["--temporary-player"]
        process.terminationHandler = { _ in try? FileManager.default.removeItem(at: cleanupDirectory) }
        try process.run()
    }
}
