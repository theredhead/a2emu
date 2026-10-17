import Foundation

/// Localized text for GamepadInput; resource lookup and formatting stay out of the UI code.
final class GamepadInputIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func directInput(name: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "directInput", tableName: "GamepadInput", bundle: bundle, value: "%1$@ (direct input)",
                comment: "GamepadInput: Formatted message. name: runtime text; keep its placeholder"),
            name)
    }

    func formattedLabel(name: String, number: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "formattedLabel", tableName: "GamepadInput", bundle: bundle, value: "%1$@ (%2$ld)",
                comment:
                    "GamepadInput: Formatted message. name: runtime text; keep its placeholder; number: numeric value"
            ),
            name, number)
    }

    var gameController: String {
        NSLocalizedString(
            "gameController", tableName: "GamepadInput", bundle: bundle, value: "Game controller",
            comment: "GamepadInput: User-visible label, instruction, or error message.")
    }

    var noGameControllerConnected: String {
        NSLocalizedString(
            "noGameControllerConnected", tableName: "GamepadInput", bundle: bundle,
            value: "No game controller connected",
            comment: "GamepadInput: User-visible label, instruction, or error message.")
    }

    var selectedControllerDisconnected: String {
        NSLocalizedString(
            "selectedControllerDisconnected", tableName: "GamepadInput", bundle: bundle,
            value: "Selected controller disconnected",
            comment: "GamepadInput: User-visible label, instruction, or error message.")
    }
}
