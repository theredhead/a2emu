import Foundation

/// Localized text for SnapshotBrowser; resource lookup and formatting stay out of the UI code.
final class SnapshotBrowserIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var browserInstructions: String {
        NSLocalizedString(
            "browserInstructions", tableName: "SnapshotBrowser", bundle: bundle,
            value: "Choose a snapshot to return to that moment. Each snapshot includes its own disk state.",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var saveInstructions: String {
        NSLocalizedString(
            "saveInstructions", tableName: "SnapshotBrowser", bundle: bundle,
            value: "Give this moment a name. Its disks and a preview will be saved with it.",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var moveThisSnapshotToTheTrash: String {
        NSLocalizedString(
            "moveThisSnapshotToTheTrash", tableName: "SnapshotBrowser", bundle: bundle,
            value: "Move this snapshot to the Trash?",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var moveToTrash: String {
        NSLocalizedString(
            "moveToTrash", tableName: "SnapshotBrowser", bundle: bundle, value: "Move to Trash",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var noSnapshotsYetSaveYourFirst: String {
        NSLocalizedString(
            "noSnapshotsYetSaveYourFirst", tableName: "SnapshotBrowser", bundle: bundle,
            value: "No snapshots yet. Save your first moment.",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var restoreSnapshot: String {
        NSLocalizedString(
            "restoreSnapshot", tableName: "SnapshotBrowser", bundle: bundle, value: "Restore Snapshot",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var restoringSnapshot: String {
        NSLocalizedString(
            "restoringSnapshot", tableName: "SnapshotBrowser", bundle: bundle, value: "Restoring snapshot…",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var saveSnapshot: String {
        NSLocalizedString(
            "saveSnapshot", tableName: "SnapshotBrowser", bundle: bundle, value: "Save Snapshot…",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var saveSnapshotTitle: String {
        NSLocalizedString(
            "saveSnapshotTitle", tableName: "SnapshotBrowser", bundle: bundle, value: "Save Snapshot",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var savedGame: String {
        NSLocalizedString(
            "savedGame", tableName: "SnapshotBrowser", bundle: bundle, value: "Saved game",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    func windowTitle(gameName: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "windowTitle", tableName: "SnapshotBrowser", bundle: bundle, value: "Saved Snapshots — %1$@",
                comment: "SnapshotBrowser: Formatted message. gameName: runtime text; keep its placeholder"),
            gameName)
    }

    func savedSnapshotCount(count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "savedSnapshotCount", tableName: "SnapshotBrowser", bundle: bundle,
                value: count == 1 ? "%ld saved snapshot" : "%ld saved snapshots",
                comment: "SnapshotBrowser: Formatted message. count: numeric value"),
            count)
    }

    var savingSnapshot: String {
        NSLocalizedString(
            "savingSnapshot", tableName: "SnapshotBrowser", bundle: bundle, value: "Saving snapshot…",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var showInFinder: String {
        NSLocalizedString(
            "showInFinder", tableName: "SnapshotBrowser", bundle: bundle, value: "Show in Finder",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var snapshotCouldNotBeCompleted: String {
        NSLocalizedString(
            "snapshotCouldNotBeCompleted", tableName: "SnapshotBrowser", bundle: bundle,
            value: "Snapshot could not be completed",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var thisSnapshotIsAlreadyInYour: String {
        NSLocalizedString(
            "thisSnapshotIsAlreadyInYour", tableName: "SnapshotBrowser", bundle: bundle,
            value: "This snapshot is already in your library.",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var thisSnapshotUsesADifferentSet: String {
        NSLocalizedString(
            "thisSnapshotUsesADifferentSet", tableName: "SnapshotBrowser", bundle: bundle,
            value: "This snapshot uses a different set of disks.",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var deleteExplanation: String {
        NSLocalizedString(
            "deleteExplanation", tableName: "SnapshotBrowser", bundle: bundle,
            value: "Your running game and its working disks will be kept.",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }

    var yourSavedMoments: String {
        NSLocalizedString(
            "yourSavedMoments", tableName: "SnapshotBrowser", bundle: bundle, value: "Your saved moments",
            comment: "SnapshotBrowser: User-visible label, instruction, or error message.")
    }
}
