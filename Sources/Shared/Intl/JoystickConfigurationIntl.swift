import Foundation

/// Localized text for JoystickConfiguration; resource lookup and formatting stay out of the UI code.
final class JoystickConfigurationIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var button0: String {
        NSLocalizedString(
            "button0", tableName: "JoystickConfiguration", bundle: bundle, value: "Button 0",
            comment: "JoystickConfiguration: User-visible label, instruction, or error message.")
    }

    var button1: String {
        NSLocalizedString(
            "button1", tableName: "JoystickConfiguration", bundle: bundle, value: "Button 1",
            comment: "JoystickConfiguration: User-visible label, instruction, or error message.")
    }

    var down: String {
        NSLocalizedString(
            "down", tableName: "JoystickConfiguration", bundle: bundle, value: "Down",
            comment: "JoystickConfiguration: User-visible label, instruction, or error message.")
    }

    func assignmentTooltip(control: String, source: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "assignmentTooltip", tableName: "JoystickConfiguration", bundle: bundle, value: "%1$@: %2$@",
                comment:
                    "JoystickConfiguration: Formatted message. control: runtime text; keep its placeholder; source: runtime text; keep its placeholder"
            ),
            control, source)
    }

    func assignmentAccessibilityLabel(control: String, source: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "assignmentAccessibilityLabel", tableName: "JoystickConfiguration", bundle: bundle,
                value: "%1$@, %2$@",
                comment:
                    "JoystickConfiguration: Formatted message. control: runtime text; keep its placeholder; source: runtime text; keep its placeholder"
            ),
            control, source)
    }

    var left: String {
        NSLocalizedString(
            "left", tableName: "JoystickConfiguration", bundle: bundle, value: "Left",
            comment: "JoystickConfiguration: User-visible label, instruction, or error message.")
    }

    var right: String {
        NSLocalizedString(
            "right", tableName: "JoystickConfiguration", bundle: bundle, value: "Right",
            comment: "JoystickConfiguration: User-visible label, instruction, or error message.")
    }

    var up: String {
        NSLocalizedString(
            "up", tableName: "JoystickConfiguration", bundle: bundle, value: "Up",
            comment: "JoystickConfiguration: User-visible label, instruction, or error message.")
    }

    var commandKeyCaption: String {
        NSLocalizedString(
            "commandKeyCaption", tableName: "JoystickConfiguration", bundle: bundle, value: "Command",
            comment: "Short key name drawn on the joystick illustration for a legacy keyboard assignment.")
    }

    var optionKeyCaption: String {
        NSLocalizedString(
            "optionKeyCaption", tableName: "JoystickConfiguration", bundle: bundle, value: "Option",
            comment: "Short key name drawn on the joystick illustration for a legacy keyboard assignment.")
    }
}
