import Foundation

/// Localized text for Player; resource lookup and formatting stay out of the UI code.
final class PlayerIntl {
    private let bundle: Bundle

    func noCompatibleDrive(filename: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "noCompatibleDrive", tableName: "Player", bundle: bundle,
                value: "No compatible drive is configured for %1$@. Add a suitable drive in the builder.",
                comment: "Disk drop message. filename: dropped disk name."), filename)
    }

    var chooseDiskDrive: String {
        NSLocalizedString(
            "chooseDiskDrive", tableName: "Player", bundle: bundle, value: "Choose a drive",
            comment: "Disk mount dialog.")
    }

    func replaceMountedDisk(filename: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "replaceMountedDisk", tableName: "Player", bundle: bundle,
                value: "All compatible drives are occupied. Choose which disk to eject before mounting %1$@.",
                comment: "Disk drop message. filename: dropped disk name."), filename)
    }

    var ejectAndMount: String {
        NSLocalizedString(
            "ejectAndMount", tableName: "Player", bundle: bundle, value: "Eject and Mount",
            comment: "Disk mount dialog.")
    }

    var saveTemporaryMediaElsewhere: String {
        NSLocalizedString(
            "saveTemporaryMediaElsewhere", tableName: "Player", bundle: bundle,
            value: "Save Temporary Media Elsewhere", comment: "Saving changed disposable disk images.")
    }

    var unsavedTemporaryMedia: String {
        NSLocalizedString(
            "unsavedTemporaryMedia", tableName: "Player", bundle: bundle,
            value: "Save changes to temporary media?", comment: "Saving changed disposable disk images.")
    }

    var saveTemporaryMediaBeforeQuitting: String {
        NSLocalizedString(
            "saveTemporaryMediaBeforeQuitting", tableName: "Player", bundle: bundle,
            value: "Temporary disks have unsaved changes. Save them to their original files before quitting?",
            comment: "Saving changed disposable disk images.")
    }

    var discardTemporaryChanges: String {
        NSLocalizedString(
            "discardTemporaryChanges", tableName: "Player", bundle: bundle, value: "Discard Changes",
            comment: "Saving changed disposable disk images.")
    }

    var couldNotSaveTemporaryMedia: String {
        NSLocalizedString(
            "couldNotSaveTemporaryMedia", tableName: "Player", bundle: bundle,
            value: "Could not save temporary media", comment: "Saving changed disposable disk images.")
    }

    var temporaryMediaTitle: String {
        NSLocalizedString(
            "temporaryMediaTitle", tableName: "Player", bundle: bundle, value: "Temporary Media",
            comment: "Pause reason while saving disposable disk images.")
    }

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var chooseADifferentDiskName: String {
        NSLocalizedString(
            "chooseADifferentDiskName", tableName: "Player", bundle: bundle,
            value: "Choose a Different Disk Name",
            comment: "Player: User-visible label, instruction, or error message.")
    }

    var couldNotRestoreStartupSnapshot: String {
        NSLocalizedString(
            "couldNotRestoreStartupSnapshot", tableName: "Player", bundle: bundle,
            value: "Could not restore startup snapshot",
            comment: "Player: User-visible label, instruction, or error message.")
    }

    var couldNotStartEmulator: String {
        NSLocalizedString(
            "couldNotStartEmulator", tableName: "Player", bundle: bundle, value: "Could not start emulator",
            comment: "Player: User-visible label, instruction, or error message.")
    }

    func customSpeedMode(mode: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "customSpeedMode", tableName: "Player", bundle: bundle, value: "Custom speed (mode %1$ld)",
                comment: "Player: Formatted message. mode: numeric value"),
            mode)
    }

    var debugger: String {
        NSLocalizedString(
            "debugger", tableName: "Player", bundle: bundle, value: "Debugger",
            comment: "Player: User-visible label, instruction, or error message.")
    }

    var invalidDiskDrop: String {
        NSLocalizedString(
            "invalidDiskDrop", tableName: "Player", bundle: bundle,
            value: "Drop disk image files to add them to this player.",
            comment: "Player: User-visible label, instruction, or error message.")
    }

    func diskNameCollision(name: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "diskNameCollision", tableName: "Player", bundle: bundle,
                value:
                    "“%1$@” is already in use or is not a valid disk filename. Enter a new name with the original disk extension; existing files will be kept.",
                comment: "Player: Formatted message. name: runtime text; keep its placeholder"),
            name)
    }

    func mhz(megahertz: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "mhz", tableName: "Player", bundle: bundle, value: "%1$ld MHz",
                comment: "Player: Formatted message. megahertz: numeric value"),
            megahertz)
    }

    func mhzInvalidSetting(megahertz: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "mhzInvalidSetting", tableName: "Player", bundle: bundle,
                value: "%1$ld MHz (invalid setting)",
                comment: "Player: Formatted message. megahertz: numeric value"),
            megahertz)
    }

    var paused: String {
        NSLocalizedString(
            "paused", tableName: "Player", bundle: bundle, value: " — Paused",
            comment: "Player: User-visible label, instruction, or error message.")
    }

    var invalidDiskLibrary: String {
        NSLocalizedString(
            "invalidDiskLibrary", tableName: "Player", bundle: bundle,
            value: "The imported disk library is invalid.",
            comment: "Player: User-visible label, instruction, or error message.")
    }

    var importLimitError: String {
        NSLocalizedString(
            "importLimitError", tableName: "Player", bundle: bundle,
            value: "This player can import up to 256 additional disks.",
            comment: "Player: User-visible label, instruction, or error message.")
    }

    var useThisName: String {
        NSLocalizedString(
            "useThisName", tableName: "Player", bundle: bundle, value: "Use This Name",
            comment: "Player: User-visible label, instruction, or error message.")
    }

    func startupRecoveryHint(errorDescription: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "startupRecoveryHint", tableName: "Player", bundle: bundle,
                value: "%1$@ You can resume to boot normally.",
                comment: "Player: Formatted message. errorDescription: runtime text; keep its placeholder"),
            errorDescription)
    }

    func pauseReason(identifier: String) -> String {
        switch identifier {
        case "About":
            return NSLocalizedString(
                "pauseReasonAbout", tableName: "Player", bundle: bundle, value: "About",
                comment: "Human-readable pause reason; the internal identity must remain unchanged.")
        case "Credits":
            return NSLocalizedString(
                "pauseReasonCredits", tableName: "Player", bundle: bundle, value: "Credits",
                comment: "Human-readable pause reason; the internal identity must remain unchanged.")
        case "Controller disconnected":
            return NSLocalizedString(
                "pauseReasonControllerdisconnected", tableName: "Player", bundle: bundle,
                value: "Controller disconnected",
                comment: "Human-readable pause reason; the internal identity must remain unchanged.")
        case "Startup snapshot could not be restored":
            return NSLocalizedString(
                "pauseReasonStartupsnapshotcouldnotberestored", tableName: "Player", bundle: bundle,
                value: "Startup snapshot could not be restored",
                comment: "Human-readable pause reason; the internal identity must remain unchanged.")
        case "Rename Disk":
            return NSLocalizedString(
                "pauseReasonRenameDisk", tableName: "Player", bundle: bundle, value: "Rename Disk",
                comment: "Human-readable pause reason; the internal identity must remain unchanged.")
        case "Controller Settings":
            return NSLocalizedString(
                "pauseReasonControllerSettings", tableName: "Player", bundle: bundle,
                value: "Controller Settings",
                comment: "Human-readable pause reason; the internal identity must remain unchanged.")
        case "Snapshots":
            return NSLocalizedString(
                "pauseReasonSnapshots", tableName: "Player", bundle: bundle, value: "Snapshots",
                comment: "Human-readable pause reason; the internal identity must remain unchanged.")
        case "ROM Setup":
            return NSLocalizedString(
                "pauseReasonROMSetup", tableName: "Player", bundle: bundle, value: "ROM Setup",
                comment: "Human-readable pause reason; the internal identity must remain unchanged.")
        case "Save Temporary Media": return temporaryMediaTitle
        case "Import Disks":
            return NSLocalizedString(
                "pauseReasonImportDisks", tableName: "Player", bundle: bundle, value: "Import Disks",
                comment: "Human-readable pause reason; the internal identity must remain unchanged.")
        case "Screenshot Error":
            return NSLocalizedString(
                "pauseReasonScreenshotError", tableName: "Player", bundle: bundle, value: "Screenshot Error",
                comment: "Human-readable pause reason; the internal identity must remain unchanged.")
        case "Snapshot recovery failed":
            return NSLocalizedString(
                "pauseReasonSnapshotrecoveryfailed", tableName: "Player", bundle: bundle,
                value: "Snapshot recovery failed",
                comment: "Human-readable pause reason; the internal identity must remain unchanged.")
        default: return identifier
        }
    }

    func pausedGameTitle(gameName: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "pausedGameTitle", tableName: "Player", bundle: bundle, value: "%1$@ — Paused",
                comment: "Window title while paused, without a reason. Preserve the game name placeholder."),
            gameName)
    }

    func pausedGameTitleWithReason(gameName: String, reason: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "pausedGameTitleWithReason", tableName: "Player", bundle: bundle,
                value: "%1$@ — Paused (%2$@)",
                comment: "Window title while paused, including a translated reason."), gameName, reason)
    }

    func pausedTitle(gameName: String, reason: String?) -> String {
        if let reason = reason {
            return pausedGameTitleWithReason(gameName: gameName, reason: pauseReason(identifier: reason))
        }
        return pausedGameTitle(gameName: gameName)
    }
}
