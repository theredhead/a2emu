import Foundation

/// Localized text for Builder; resource lookup and formatting stay out of the UI code.
final class BuilderIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var aboutAppleIigsPlayerBuilder: String {
        NSLocalizedString(
            "aboutAppleIigsPlayerBuilder", tableName: "Builder", bundle: bundle,
            value: "About Apple IIGS Player Builder",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var addToPlayerDisks: String {
        NSLocalizedString(
            "addToPlayerDisks", tableName: "Builder", bundle: bundle, value: "Add to this player's disks",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var appName: String {
        NSLocalizedString(
            "appName", tableName: "Builder", bundle: bundle, value: "App name:",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var appNamePlaceholder: String {
        NSLocalizedString(
            "appNamePlaceholder", tableName: "Builder", bundle: bundle, value: "Name of the exported app",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var appleIigsPlayerBuilder: String {
        NSLocalizedString(
            "appleIigsPlayerBuilder", tableName: "Builder", bundle: bundle,
            value: "Apple IIGS Player Builder",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var bundledStartupSnapshot: String {
        NSLocalizedString(
            "bundledStartupSnapshot", tableName: "Builder", bundle: bundle, value: "Bundled startup snapshot",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var chooseADiskFirst: String {
        NSLocalizedString(
            "chooseADiskFirst", tableName: "Builder", bundle: bundle, value: "Choose a disk first.",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var selectedDiskOverwriteError: String {
        NSLocalizedString(
            "selectedDiskOverwriteError", tableName: "Builder", bundle: bundle,
            value: "Choose a new file instead of replacing a disk selected in this player.",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var chooseDisks: String {
        NSLocalizedString(
            "chooseDisks", tableName: "Builder", bundle: bundle, value: "Choose Disks…",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var chooseDisksHint: String {
        NSLocalizedString(
            "chooseDisksHint", tableName: "Builder", bundle: bundle, value: "Choose disk images to package.",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var emptyPlayerHint: String {
        NSLocalizedString(
            "emptyPlayerHint", tableName: "Builder", bundle: bundle,
            value: "Choose disks, or drop an existing player here to edit it.",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var choosePlayerIcon: String {
        NSLocalizedString(
            "choosePlayerIcon", tableName: "Builder", bundle: bundle, value: "Choose Player Icon…",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var snapshotDiskSetHint: String {
        NSLocalizedString(
            "snapshotDiskSetHint", tableName: "Builder", bundle: bundle,
            value: "Clear the startup snapshot before changing its disk set.",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var couldNotUpdatePlayer: String {
        NSLocalizedString(
            "couldNotUpdatePlayer", tableName: "Builder", bundle: bundle, value: "Could not update player",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var blankDiskExplanation: String {
        NSLocalizedString(
            "blankDiskExplanation", tableName: "Builder", bundle: bundle,
            value:
                "Create an empty writable disk. Initialize it inside the emulated computer before saving files to it. Blank disks do not contain a bootable system.",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var createPlayer: String {
        NSLocalizedString(
            "createPlayer", tableName: "Builder", bundle: bundle, value: "Create Player…",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var createPlayerHeading: String {
        NSLocalizedString(
            "createPlayerHeading", tableName: "Builder", bundle: bundle,
            value: "Create a standalone Apple IIGS player",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    func diskImagesSelected(count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "diskImagesSelected", tableName: "Builder", bundle: bundle,
                value: count == 1 ? "%ld disk image selected" : "%ld disk images selected",
                comment: "Builder: Formatted message. count: numeric value"),
            count)
    }

    var diskNamesAndInitialDrives: String {
        NSLocalizedString(
            "diskNamesAndInitialDrives", tableName: "Builder", bundle: bundle,
            value: "Disk names and initial drives",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    func drives(title: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "drives", tableName: "Builder", bundle: bundle, value: "%1$@ drives:",
                comment: "Builder: Formatted message. title: runtime text; keep its placeholder"),
            title)
    }

    var invalidDropError: String {
        NSLocalizedString(
            "invalidDropError", tableName: "Builder", bundle: bundle,
            value: "Drop disk images, one snapshot, or one existing player.",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    func edit(filename: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "edit", tableName: "Builder", bundle: bundle, value: "Edit %1$@",
                comment: "Builder: Formatted message. filename: runtime text; keep its placeholder"),
            filename)
    }

    var editThisAppleIigsPlayer: String {
        NSLocalizedString(
            "editThisAppleIigsPlayer", tableName: "Builder", bundle: bundle,
            value: "Edit this Apple IIGS player",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    func editing(filename: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "editing", tableName: "Builder", bundle: bundle, value: "Editing %1$@",
                comment: "Builder: Formatted message. filename: runtime text; keep its placeholder"),
            filename)
    }

    var expansionRAMHint: String {
        NSLocalizedString(
            "expansionRAMHint", tableName: "Builder", bundle: bundle,
            value:
                "Additional RAM beyond the ROM model's built-in memory. ROM 01 starts with 256 KB; ROM 03 has about 1 MB.",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var expansionRam: String {
        NSLocalizedString(
            "expansionRam", tableName: "Builder", bundle: bundle, value: "Expansion RAM:",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var initialSpeed: String {
        NSLocalizedString(
            "initialSpeed", tableName: "Builder", bundle: bundle, value: "Initial speed:",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    func kilobytes(kilobytes: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "kilobytes", tableName: "Builder", bundle: bundle, value: "%1$ld KB",
                comment: "Builder: Formatted message. kilobytes: numeric value"),
            kilobytes)
    }

    var unmountedDisksHint: String {
        NSLocalizedString(
            "unmountedDisksHint", tableName: "Builder", bundle: bundle,
            value: "Leave extra images unmounted; swap them into a drive later through the Disks menu.",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    func megabytes(megabytes: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "megabytes", tableName: "Builder", bundle: bundle, value: "%1$ld MB",
                comment: "Builder: Formatted message. megabytes: numeric value"),
            megabytes)
    }

    var newBlankDiskImage: String {
        NSLocalizedString(
            "newBlankDiskImage", tableName: "Builder", bundle: bundle, value: "New Blank Disk Image…",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var blankDiskTitle: String {
        NSLocalizedString(
            "blankDiskTitle", tableName: "Builder", bundle: bundle, value: "New Blank Disk Image",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var newPlayer: String {
        NSLocalizedString(
            "newPlayer", tableName: "Builder", bundle: bundle, value: "New Player",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var noneBuiltInOnly: String {
        NSLocalizedString(
            "noneBuiltInOnly", tableName: "Builder", bundle: bundle, value: "None (built-in only)",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var normalStartup: String {
        NSLocalizedString(
            "normalStartup", tableName: "Builder", bundle: bundle, value: "No snapshot — normal startup",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var notInitiallyMounted: String {
        NSLocalizedString(
            "notInitiallyMounted", tableName: "Builder", bundle: bundle, value: "Not initially mounted",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var openPlayer: String {
        NSLocalizedString(
            "openPlayer", tableName: "Builder", bundle: bundle, value: "Open Player…",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var startupSnapshotHint: String {
        NSLocalizedString(
            "startupSnapshotHint", tableName: "Builder", bundle: bundle,
            value: "Optional: restore the captured speed and disk state on every launch.",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var quitPlayerBeforeSavingError: String {
        NSLocalizedString(
            "quitPlayerBeforeSavingError", tableName: "Builder", bundle: bundle,
            value: "Quit this player before saving changes.",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var removeSnapshotHint: String {
        NSLocalizedString(
            "removeSnapshotHint", tableName: "Builder", bundle: bundle,
            value: "Remove startup snapshot and use normal startup",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var saveBlankDiskImage: String {
        NSLocalizedString(
            "saveBlankDiskImage", tableName: "Builder", bundle: bundle, value: "Save Blank Disk Image",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    func savedChangesTo(filename: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "savedChangesTo", tableName: "Builder", bundle: bundle, value: "Saved changes to %1$@",
                comment: "Builder: Formatted message. filename: runtime text; keep its placeholder"),
            filename)
    }

    var bootFloppy35: String {
        NSLocalizedString(
            "bootFloppy35", tableName: "Builder", bundle: bundle, value: "Slot 5 — 3.5-inch floppy",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var bootFloppy525: String {
        NSLocalizedString(
            "bootFloppy525", tableName: "Builder", bundle: bundle, value: "Slot 6 — 5.25-inch floppy",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var bootSmartPort: String {
        NSLocalizedString(
            "bootSmartPort", tableName: "Builder", bundle: bundle, value: "Slot 7 — hard disk / SmartPort",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var snapshotSpeedHint: String {
        NSLocalizedString(
            "snapshotSpeedHint", tableName: "Builder", bundle: bundle,
            value: "The startup snapshot restores its captured speed.",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var startInFullScreen: String {
        NSLocalizedString(
            "startInFullScreen", tableName: "Builder", bundle: bundle, value: "Start in full screen",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var startUpFrom: String {
        NSLocalizedString(
            "startUpFrom", tableName: "Builder", bundle: bundle, value: "Start up from:",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var startupSnapshot: String {
        NSLocalizedString(
            "startupSnapshot", tableName: "Builder", bundle: bundle, value: "Startup Snapshot…",
            comment: "Builder: User-visible label, instruction, or error message.")
    }

    var removeStartupSnapshot: String {
        NSLocalizedString(
            "removeStartupSnapshot", tableName: "Builder", bundle: bundle, value: "Remove startup snapshot",
            comment: "Accessibility label for the clear snapshot button.")
    }

    func untitledDisk(fileExtension: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "untitledDisk", tableName: "Builder", bundle: bundle, value: "Untitled.%1$@",
                comment:
                    "Suggested new disk filename. The extension is a technical identifier and must be preserved."
            ), fileExtension)
    }
}
