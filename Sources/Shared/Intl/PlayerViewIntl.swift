import Foundation

/// Localized text for PlayerView; resource lookup and formatting stay out of the UI code.
final class PlayerViewIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var chooseADriveInTheDisks: String {
        NSLocalizedString(
            "chooseADriveInTheDisks", tableName: "PlayerView", bundle: bundle,
            value:
                "Choose a drive in the Disks menu to insert an added image. Your current disks remain mounted.",
            comment: "PlayerView: User-visible label, instruction, or error message.")
    }

    var couldNotAddDisks: String {
        NSLocalizedString(
            "couldNotAddDisks", tableName: "PlayerView", bundle: bundle, value: "Could Not Add Disks",
            comment: "PlayerView: User-visible label, instruction, or error message.")
    }

    var couldNotSaveScreenshot: String {
        NSLocalizedString(
            "couldNotSaveScreenshot", tableName: "PlayerView", bundle: bundle,
            value: "Could not save screenshot",
            comment: "PlayerView: User-visible label, instruction, or error message.")
    }

    var disksAdded: String {
        NSLocalizedString(
            "disksAdded", tableName: "PlayerView", bundle: bundle, value: "Disks Added",
            comment: "PlayerView: User-visible label, instruction, or error message.")
    }

    var noGameFrameIsAvailableTo: String {
        NSLocalizedString(
            "noGameFrameIsAvailableTo", tableName: "PlayerView", bundle: bundle,
            value: "No game frame is available to capture yet.",
            comment: "PlayerView: User-visible label, instruction, or error message.")
    }
}
