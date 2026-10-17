import Foundation

/// Localized text for KeyboardConfiguration; resource lookup and formatting stay out of the UI code.
final class KeyboardConfigurationIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var bindAdbMouseButton: String {
        NSLocalizedString(
            "bindAdbMouseButton", tableName: "KeyboardConfiguration", bundle: bundle,
            value: "Bind ADB mouse button",
            comment: "KeyboardConfiguration: User-visible label, instruction, or error message.")
    }

    var bindAdbMouseMovement: String {
        NSLocalizedString(
            "bindAdbMouseMovement", tableName: "KeyboardConfiguration", bundle: bundle,
            value: "Bind ADB mouse movement",
            comment: "KeyboardConfiguration: User-visible label, instruction, or error message.")
    }

    var clickThenMoveEitherStickOr: String {
        NSLocalizedString(
            "clickThenMoveEitherStickOr", tableName: "KeyboardConfiguration", bundle: bundle,
            value: "Click, then move either stick or the D-pad to bind all four mouse directions",
            comment: "KeyboardConfiguration: User-visible label, instruction, or error message.")
    }

    var clickToBindAControllerInput: String {
        NSLocalizedString(
            "clickToBindAControllerInput", tableName: "KeyboardConfiguration", bundle: bundle,
            value: "Click to bind a controller input",
            comment: "KeyboardConfiguration: User-visible label, instruction, or error message.")
    }

    var clickToBindThisMouseDirection: String {
        NSLocalizedString(
            "clickToBindThisMouseDirection", tableName: "KeyboardConfiguration", bundle: bundle,
            value: "Click to bind this mouse direction",
            comment: "KeyboardConfiguration: User-visible label, instruction, or error message.")
    }

    func bindMouseDirection(direction: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "bindMouseDirection", tableName: "KeyboardConfiguration", bundle: bundle,
                value: "Bind mouse %1$@",
                comment:
                    "Accessibility label for one mouse direction control; direction is a translated direction name."
            ), direction)
    }

    func mouseClickBindings(bindings: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "mouseClickBindings", tableName: "KeyboardConfiguration", bundle: bundle,
                value: "Mouse click: %1$@",
                comment: "Mouse button tooltip; bindings is a list of controller input symbols or Unassigned."
            ), bindings)
    }
}
