import Foundation

/// Localized text for BlankDisk; resource lookup and formatting stay out of the UI code.
final class BlankDiskIntl {
    private let bundle: Bundle

    var unformatted: String {
        NSLocalizedString(
            "unformatted", tableName: "BlankDisk", bundle: bundle, value: "Unformatted",
            comment: "Disk creation option or validation message.")
    }

    var incompatibleFormat: String {
        NSLocalizedString(
            "incompatibleFormat", tableName: "BlankDisk", bundle: bundle,
            value: "DOS 3.3 requires a 140 KB 5.25-inch disk.",
            comment: "Disk creation option or validation message.")
    }

    var dos33DataDisk: String {
        NSLocalizedString(
            "dos33DataDisk", tableName: "BlankDisk", bundle: bundle, value: "DOS 3.3 — data disk",
            comment: "DOS 3.3 filesystem without DOS system tracks; usable as data storage, not bootable.")
    }

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var floppy35: String {
        NSLocalizedString(
            "floppy35", tableName: "BlankDisk", bundle: bundle, value: "3.5-inch floppy — 800 KB",
            comment: "BlankDisk: User-visible label, instruction, or error message.")
    }

    var floppy525: String {
        NSLocalizedString(
            "floppy525", tableName: "BlankDisk", bundle: bundle, value: "5.25-inch floppy — 140 KB",
            comment: "BlankDisk: User-visible label, instruction, or error message.")
    }

    var smartportHardDisk10Mb: String {
        NSLocalizedString(
            "smartportHardDisk10Mb", tableName: "BlankDisk", bundle: bundle,
            value: "SmartPort hard disk — 10 MB",
            comment: "BlankDisk: User-visible label, instruction, or error message.")
    }

    var smartportHardDisk20Mb: String {
        NSLocalizedString(
            "smartportHardDisk20Mb", tableName: "BlankDisk", bundle: bundle,
            value: "SmartPort hard disk — 20 MB",
            comment: "BlankDisk: User-visible label, instruction, or error message.")
    }

    var smartportHardDisk32Mb: String {
        NSLocalizedString(
            "smartportHardDisk32Mb", tableName: "BlankDisk", bundle: bundle,
            value: "SmartPort hard disk — 32 MB",
            comment: "BlankDisk: User-visible label, instruction, or error message.")
    }

    var smartportHardDisk5Mb: String {
        NSLocalizedString(
            "smartportHardDisk5Mb", tableName: "BlankDisk", bundle: bundle,
            value: "SmartPort hard disk — 5 MB",
            comment: "BlankDisk: User-visible label, instruction, or error message.")
    }
}
