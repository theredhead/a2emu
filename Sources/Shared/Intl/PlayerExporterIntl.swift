import Foundation

/// Localized text for PlayerExporter; resource lookup and formatting stay out of the UI code.
final class PlayerExporterIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var chooseAnA2EmuPlayerApp: String {
        NSLocalizedString(
            "chooseAnA2EmuPlayerApp", tableName: "PlayerExporter", bundle: bundle,
            value: "Choose an a2emu player app.",
            comment: "PlayerExporter: User-visible label, instruction, or error message.")
    }

    var couldNotPrepareTheStartupSnapshot: String {
        NSLocalizedString(
            "couldNotPrepareTheStartupSnapshot", tableName: "PlayerExporter", bundle: bundle,
            value: "Could not prepare the startup snapshot for signing.",
            comment: "PlayerExporter: User-visible label, instruction, or error message.")
    }

    var couldNotSignTheExportedPlayer: String {
        NSLocalizedString(
            "couldNotSignTheExportedPlayer", tableName: "PlayerExporter", bundle: bundle,
            value: "Could not sign the exported player.",
            comment: "PlayerExporter: User-visible label, instruction, or error message.")
    }

    var eachDiskMustHaveADifferent: String {
        NSLocalizedString(
            "eachDiskMustHaveADifferent", tableName: "PlayerExporter", bundle: bundle,
            value: "Each disk must have a different filename.",
            comment: "PlayerExporter: User-visible label, instruction, or error message.")
    }

    var thatAppAlreadyExistsChooseA: String {
        NSLocalizedString(
            "thatAppAlreadyExistsChooseA", tableName: "PlayerExporter", bundle: bundle,
            value: "That app already exists. Choose a new name or location.",
            comment: "PlayerExporter: User-visible label, instruction, or error message.")
    }

    var theBundledStartupSnapshotUsesDifferent: String {
        NSLocalizedString(
            "theBundledStartupSnapshotUsesDifferent", tableName: "PlayerExporter", bundle: bundle,
            value: "The bundled startup snapshot uses different disks.",
            comment: "PlayerExporter: User-visible label, instruction, or error message.")
    }

    var theStartupSnapshotMustUseThis: String {
        NSLocalizedString(
            "theStartupSnapshotMustUseThis", tableName: "PlayerExporter", bundle: bundle,
            value: "The startup snapshot must use this player's disks and available drives.",
            comment: "PlayerExporter: User-visible label, instruction, or error message.")
    }

    var thisPlayerHasNoApplicationIdentifier: String {
        NSLocalizedString(
            "thisPlayerHasNoApplicationIdentifier", tableName: "PlayerExporter", bundle: bundle,
            value: "This player has no application identifier.",
            comment: "PlayerExporter: User-visible label, instruction, or error message.")
    }

    var thisPlayerIsMissingABundled: String {
        NSLocalizedString(
            "thisPlayerIsMissingABundled", tableName: "PlayerExporter", bundle: bundle,
            value: "This player is missing a bundled disk image.",
            comment: "PlayerExporter: User-visible label, instruction, or error message.")
    }
}
