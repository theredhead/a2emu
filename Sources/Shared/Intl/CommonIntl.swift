import Foundation

/// Localized text for Common; resource lookup and formatting stay out of the UI code.
final class CommonIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var browse: String {
        NSLocalizedString(
            "browse", tableName: "Common", bundle: bundle, value: "Browse…",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var cancel: String {
        NSLocalizedString(
            "cancel", tableName: "Common", bundle: bundle, value: "Cancel",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var close: String {
        NSLocalizedString(
            "close", tableName: "Common", bundle: bundle, value: "Close",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var continueAction: String {
        NSLocalizedString(
            "continueAction", tableName: "Common", bundle: bundle, value: "Continue…",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var deleteAction: String {
        NSLocalizedString(
            "deleteAction", tableName: "Common", bundle: bundle, value: "Delete…",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var file: String {
        NSLocalizedString(
            "file", tableName: "Common", bundle: bundle, value: "File",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var importAction: String {
        NSLocalizedString(
            "importAction", tableName: "Common", bundle: bundle, value: "Import…",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var pause: String {
        NSLocalizedString(
            "pause", tableName: "Common", bundle: bundle, value: "Pause",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var quit: String {
        NSLocalizedString(
            "quit", tableName: "Common", bundle: bundle, value: "Quit",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var reset: String {
        NSLocalizedString(
            "reset", tableName: "Common", bundle: bundle, value: "Reset",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var resume: String {
        NSLocalizedString(
            "resume", tableName: "Common", bundle: bundle, value: "Resume",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var save: String {
        NSLocalizedString(
            "save", tableName: "Common", bundle: bundle, value: "Save",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var snapshots: String {
        NSLocalizedString(
            "snapshots", tableName: "Common", bundle: bundle, value: "Snapshots…",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var unassigned: String {
        NSLocalizedString(
            "unassigned", tableName: "Common", bundle: bundle, value: "Unassigned",
            comment: "Common: User-visible label, instruction, or error message.")
    }

    var floppy525Type: String {
        NSLocalizedString(
            "floppy525Type", tableName: "Common", bundle: bundle, value: "5.25-inch",
            comment: "Floppy drive size used in a UI label. Preserve the numeric size.")
    }

    var floppy35Type: String {
        NSLocalizedString(
            "floppy35Type", tableName: "Common", bundle: bundle, value: "3.5-inch",
            comment: "Floppy drive size used in a UI label. Preserve the numeric size.")
    }
}
