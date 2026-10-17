import Foundation

/// Localized text for PlayerManifest; resource lookup and formatting stay out of the UI code.
final class PlayerManifestIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var oneMHz: String {
        NSLocalizedString(
            "oneMHz", tableName: "PlayerManifest", bundle: bundle, value: "1.0 MHz",
            comment: "PlayerManifest: User-visible label, instruction, or error message.")
    }

    var twoPointEightMHz: String {
        NSLocalizedString(
            "twoPointEightMHz", tableName: "PlayerManifest", bundle: bundle, value: "2.8 MHz",
            comment: "PlayerManifest: User-visible label, instruction, or error message.")
    }

    var eightMHz: String {
        NSLocalizedString(
            "eightMHz", tableName: "PlayerManifest", bundle: bundle, value: "8 MHz",
            comment: "PlayerManifest: User-visible label, instruction, or error message.")
    }

    var appleIiPlayer: String {
        NSLocalizedString(
            "appleIiPlayer", tableName: "PlayerManifest", bundle: bundle, value: "Apple II Player",
            comment: "PlayerManifest: User-visible label, instruction, or error message.")
    }

    var chooseASupportedExpansionRamSize: String {
        NSLocalizedString(
            "chooseASupportedExpansionRamSize", tableName: "PlayerManifest", bundle: bundle,
            value: "Choose a supported expansion RAM size.",
            comment: "PlayerManifest: User-visible label, instruction, or error message.")
    }

    var chooseSlot56Or7: String {
        NSLocalizedString(
            "chooseSlot56Or7", tableName: "PlayerManifest", bundle: bundle,
            value: "Choose slot 5, 6 or 7 and at least one disk.",
            comment: "PlayerManifest: User-visible label, instruction, or error message.")
    }

    func drive(kind: String, number: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "drive", tableName: "PlayerManifest", bundle: bundle, value: "%1$@ Drive %2$ld",
                comment:
                    "PlayerManifest: Formatted message. kind: runtime text; keep its placeholder; number: numeric value"
            ),
            kind, number)
    }

    var enterAnAppNameWithoutSlashes: String {
        NSLocalizedString(
            "enterAnAppNameWithoutSlashes", tableName: "PlayerManifest", bundle: bundle,
            value: "Enter an app name without slashes, colons or control characters.",
            comment: "PlayerManifest: User-visible label, instruction, or error message.")
    }

    var giveEachDiskANameWithout: String {
        NSLocalizedString(
            "giveEachDiskANameWithout", tableName: "PlayerManifest", bundle: bundle,
            value: "Give each disk a name without control characters.",
            comment: "PlayerManifest: User-visible label, instruction, or error message.")
    }

    var initialDisksMustUseAnAvailable: String {
        NSLocalizedString(
            "initialDisksMustUseAnAvailable", tableName: "PlayerManifest", bundle: bundle,
            value: "Initial disks must use an available drive.",
            comment: "PlayerManifest: User-visible label, instruction, or error message.")
    }

    var mountABootDiskInDrive: String {
        NSLocalizedString(
            "mountABootDiskInDrive", tableName: "PlayerManifest", bundle: bundle,
            value:
                "Mount a boot disk in drive 1 of the startup slot, and assign each image to a separate drive.",
            comment: "PlayerManifest: User-visible label, instruction, or error message.")
    }

    func smartportDrive(number: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "smartportDrive", tableName: "PlayerManifest", bundle: bundle, value: "SmartPort Drive %1$ld",
                comment: "PlayerManifest: Formatted message. number: numeric value"),
            number)
    }

    var thePlayerMachineConfigurationIsInvalid: String {
        NSLocalizedString(
            "thePlayerMachineConfigurationIsInvalid", tableName: "PlayerManifest", bundle: bundle,
            value: "The player machine configuration is invalid.",
            comment: "PlayerManifest: User-visible label, instruction, or error message.")
    }

    var unlimited: String {
        NSLocalizedString(
            "unlimited", tableName: "PlayerManifest", bundle: bundle, value: "Unlimited",
            comment: "PlayerManifest: User-visible label, instruction, or error message.")
    }
}
