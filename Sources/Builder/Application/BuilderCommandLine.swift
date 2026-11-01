import Foundation

/// Runs the noninteractive export workflow before AppKit is initialized.
enum BuilderCommandLine {
    static func run(arguments: [String]) throws -> Bool {
        guard arguments.contains("--export") else { return false }

        let args = arguments

        func value(_ flag: String) -> String {
            args[args.firstIndex(of: flag)! + 1]
        }

        let disk = URL(fileURLWithPath: value("--export"))
        let bootSlot =
            args.contains("--boot-slot")
            ? Int(value("--boot-slot"))! : DiskImageDevice.detect(disk).slot
        try PlayerExporter.export(
            disks: [disk], slot: bootSlot,
            template: URL(fileURLWithPath: value("--template")),
            destination: URL(fileURLWithPath: value("--output")),
            displayName: args.contains("--name") ? value("--name") : nil,
            startupSnapshot: args.contains("--snapshot")
                ? URL(fileURLWithPath: value("--snapshot")) : nil)
        print("Player exported.")
        return true
    }
}
