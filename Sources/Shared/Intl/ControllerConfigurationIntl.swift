import Foundation

/// Localized text for ControllerConfiguration; resource lookup and formatting stay out of the UI code.
final class ControllerConfigurationIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var activeGameController: String {
        NSLocalizedString(
            "activeGameController", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Active game controller",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var appleIiAnalogJoystick: String {
        NSLocalizedString(
            "appleIiAnalogJoystick", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Apple II Analog Joystick",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var automatic: String {
        NSLocalizedString(
            "automatic", tableName: "ControllerConfiguration", bundle: bundle, value: "Automatic",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var backslash: String {
        NSLocalizedString(
            "backslash", tableName: "ControllerConfiguration", bundle: bundle, value: "Backslash",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var backtick: String {
        NSLocalizedString(
            "backtick", tableName: "ControllerConfiguration", bundle: bundle, value: "Backtick",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    func boundTo(bindings: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "boundTo", tableName: "ControllerConfiguration", bundle: bundle, value: "Bound to: %1$@",
                comment:
                    "ControllerConfiguration: Formatted message. bindings: runtime text; keep its placeholder"
            ),
            bindings)
    }

    var buttonInstructions: String {
        NSLocalizedString(
            "buttonInstructions", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Choose the controller button that should press this orange joystick button.",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var capsLock: String {
        NSLocalizedString(
            "capsLock", tableName: "ControllerConfiguration", bundle: bundle, value: "Caps Lock",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var clearKeyBindings: String {
        NSLocalizedString(
            "clearKeyBindings", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Clear Key Bindings",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var clearMouseBinding: String {
        NSLocalizedString(
            "clearMouseBinding", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Clear Mouse Binding",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var idleBindingHint: String {
        NSLocalizedString(
            "idleBindingHint", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Click a key, then activate a controller input.",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var commandOpenApple: String {
        NSLocalizedString(
            "commandOpenApple", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Command / Open Apple",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var configureControls: String {
        NSLocalizedString(
            "configureControls", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Configure Controls",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var control: String {
        NSLocalizedString(
            "control", tableName: "ControllerConfiguration", bundle: bundle, value: "Control",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var controller: String {
        NSLocalizedString(
            "controller", tableName: "ControllerConfiguration", bundle: bundle, value: "Controller",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    func controllerAssignment(control: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "controllerAssignment", tableName: "ControllerConfiguration", bundle: bundle,
                value: "%1$@ controller assignment",
                comment:
                    "ControllerConfiguration: Formatted message. control: runtime text; keep its placeholder"),
            control)
    }

    var controllerButton: String {
        NSLocalizedString(
            "controllerButton", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Controller button",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var controllerDeadZone: String {
        NSLocalizedString(
            "controllerDeadZone", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Controller dead zone",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var controllerMovement: String {
        NSLocalizedString(
            "controllerMovement", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Controller movement",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var dPad: String {
        NSLocalizedString(
            "dPad", tableName: "ControllerConfiguration", bundle: bundle, value: "D-pad",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    func dPadDirection(direction: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "dPadDirection", tableName: "ControllerConfiguration", bundle: bundle, value: "D-pad %1$@",
                comment:
                    "ControllerConfiguration: Formatted message. direction: runtime text; keep its placeholder"
            ),
            direction)
    }

    func deadZone(percent: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "deadZone", tableName: "ControllerConfiguration", bundle: bundle, value: "Dead zone: %1$ld%%",
                comment: "ControllerConfiguration: Formatted message. percent: numeric value"),
            percent)
    }

    var initialDeadZone: String {
        NSLocalizedString(
            "initialDeadZone", tableName: "ControllerConfiguration", bundle: bundle, value: "Dead zone: 8%",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var delete: String {
        NSLocalizedString(
            "delete", tableName: "ControllerConfiguration", bundle: bundle, value: "Delete",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    func direction(control: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "direction", tableName: "ControllerConfiguration", bundle: bundle, value: "%1$@ direction",
                comment:
                    "ControllerConfiguration: Formatted message. control: runtime text; keep its placeholder"),
            control)
    }

    var directionInstructions: String {
        NSLocalizedString(
            "directionInstructions", tableName: "ControllerConfiguration", bundle: bundle,
            value:
                "All four directions follow the movement source below. Move your controller to test the stick and orange buttons.",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    func disconnected(name: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "disconnected", tableName: "ControllerConfiguration", bundle: bundle,
                value: "%1$@ (disconnected)",
                comment:
                    "ControllerConfiguration: Formatted message. name: runtime text; keep its placeholder"),
            name)
    }

    var disconnectedControllerHint: String {
        NSLocalizedString(
            "disconnectedControllerHint", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Selected controller disconnected · Choose a connected controller.",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var down: String {
        NSLocalizedString(
            "down", tableName: "ControllerConfiguration", bundle: bundle, value: "Down",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var downArrow: String {
        NSLocalizedString(
            "downArrow", tableName: "ControllerConfiguration", bundle: bundle, value: "Down arrow",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var escape: String {
        NSLocalizedString(
            "escape", tableName: "ControllerConfiguration", bundle: bundle, value: "Escape",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var invertHorizontal: String {
        NSLocalizedString(
            "invertHorizontal", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Invert horizontal",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var invertVertical: String {
        NSLocalizedString(
            "invertVertical", tableName: "ControllerConfiguration", bundle: bundle, value: "Invert vertical",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    func joystick(control: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "joystick", tableName: "ControllerConfiguration", bundle: bundle, value: "Joystick %1$@",
                comment:
                    "ControllerConfiguration: Formatted message. control: runtime text; keep its placeholder"),
            control)
    }

    var joystickInstructions: String {
        NSLocalizedString(
            "joystickInstructions", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Choose a control on the left, then assign your controller on the right.",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var joystickSettings: String {
        NSLocalizedString(
            "joystickSettings", tableName: "ControllerConfiguration", bundle: bundle,
            value: "🕹️ Joystick Settings",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var key: String {
        NSLocalizedString(
            "key", tableName: "ControllerConfiguration", bundle: bundle, value: "Key",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keyboardInstructions: String {
        NSLocalizedString(
            "keyboardInstructions", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Choose a key or mouse control, then activate the controller input to bind it.",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keyboardMouse: String {
        NSLocalizedString(
            "keyboardMouse", tableName: "ControllerConfiguration", bundle: bundle, value: "Keyboard & Mouse",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keyboardMouseSettings: String {
        NSLocalizedString(
            "keyboardMouseSettings", tableName: "ControllerConfiguration", bundle: bundle,
            value: "⌨️ Keyboard & Mouse Settings",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypad0: String {
        NSLocalizedString(
            "keypad0", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad 0",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypad1: String {
        NSLocalizedString(
            "keypad1", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad 1",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypad2: String {
        NSLocalizedString(
            "keypad2", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad 2",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypad3: String {
        NSLocalizedString(
            "keypad3", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad 3",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypad4: String {
        NSLocalizedString(
            "keypad4", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad 4",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypad5: String {
        NSLocalizedString(
            "keypad5", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad 5",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypad6: String {
        NSLocalizedString(
            "keypad6", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad 6",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypad7: String {
        NSLocalizedString(
            "keypad7", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad 7",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypad8: String {
        NSLocalizedString(
            "keypad8", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad 8",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypad9: String {
        NSLocalizedString(
            "keypad9", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad 9",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypadClear: String {
        NSLocalizedString(
            "keypadClear", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad Clear",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypadDecimal: String {
        NSLocalizedString(
            "keypadDecimal", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad .",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypadDivide: String {
        NSLocalizedString(
            "keypadDivide", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad /",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypadEnter: String {
        NSLocalizedString(
            "keypadEnter", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad Enter",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypadEquals: String {
        NSLocalizedString(
            "keypadEquals", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad =",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypadMinus: String {
        NSLocalizedString(
            "keypadMinus", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad -",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypadMultiply: String {
        NSLocalizedString(
            "keypadMultiply", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad *",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var keypadPlus: String {
        NSLocalizedString(
            "keypadPlus", tableName: "ControllerConfiguration", bundle: bundle, value: "Keypad +",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var left: String {
        NSLocalizedString(
            "left", tableName: "ControllerConfiguration", bundle: bundle, value: "Left",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var leftAnalogStickDPad: String {
        NSLocalizedString(
            "leftAnalogStickDPad", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Left analog stick + D-pad",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var leftArrow: String {
        NSLocalizedString(
            "leftArrow", tableName: "ControllerConfiguration", bundle: bundle, value: "Left arrow",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var leftShoulder: String {
        NSLocalizedString(
            "leftShoulder", tableName: "ControllerConfiguration", bundle: bundle, value: "Left shoulder",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    func leftStick(direction: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "leftStick", tableName: "ControllerConfiguration", bundle: bundle, value: "Left stick %1$@",
                comment:
                    "ControllerConfiguration: Formatted message. direction: runtime text; keep its placeholder"
            ),
            direction)
    }

    var leftTrigger: String {
        NSLocalizedString(
            "leftTrigger", tableName: "ControllerConfiguration", bundle: bundle, value: "Left trigger",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var liveInputPreview: String {
        NSLocalizedString(
            "liveInputPreview", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Live input preview",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var lowerLeft: String {
        NSLocalizedString(
            "lowerLeft", tableName: "ControllerConfiguration", bundle: bundle, value: "Lower left",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var lowerRight: String {
        NSLocalizedString(
            "lowerRight", tableName: "ControllerConfiguration", bundle: bundle, value: "Lower right",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var menuStart: String {
        NSLocalizedString(
            "menuStart", tableName: "ControllerConfiguration", bundle: bundle, value: "Menu / Start",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var mouseButton: String {
        NSLocalizedString(
            "mouseButton", tableName: "ControllerConfiguration", bundle: bundle, value: "Mouse Button",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var mouseDown: String {
        NSLocalizedString(
            "mouseDown", tableName: "ControllerConfiguration", bundle: bundle, value: "Mouse Down",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var mouseLeft: String {
        NSLocalizedString(
            "mouseLeft", tableName: "ControllerConfiguration", bundle: bundle, value: "Mouse Left",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var mouseMovement: String {
        NSLocalizedString(
            "mouseMovement", tableName: "ControllerConfiguration", bundle: bundle, value: "Mouse Movement",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var mouseRight: String {
        NSLocalizedString(
            "mouseRight", tableName: "ControllerConfiguration", bundle: bundle, value: "Mouse Right",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var mouseUp: String {
        NSLocalizedString(
            "mouseUp", tableName: "ControllerConfiguration", bundle: bundle, value: "Mouse Up",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var previewHint: String {
        NSLocalizedString(
            "previewHint", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Move your controller to preview. Click a control to assign it.",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var noControllerHint: String {
        NSLocalizedString(
            "noControllerHint", tableName: "ControllerConfiguration", bundle: bundle,
            value: "No controller connected · Assignments can still be edited.",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var optionClosedApple: String {
        NSLocalizedString(
            "optionClosedApple", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Option / Closed Apple",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var optionsSelect: String {
        NSLocalizedString(
            "optionsSelect", tableName: "ControllerConfiguration", bundle: bundle, value: "Options / Select",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var mouseMovementBindingHint: String {
        NSLocalizedString(
            "mouseMovementBindingHint", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Release the controller, then move a stick or D-pad. This replaces its keyboard bindings.",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    func keyBindingHint(name: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "keyBindingHint", tableName: "ControllerConfiguration", bundle: bundle,
                value: "Release the controller, then press a button or move in a direction to bind %1$@.",
                comment:
                    "ControllerConfiguration: Formatted message. name: runtime text; keep its placeholder"),
            name)
    }

    var mouseButtonBindingHint: String {
        NSLocalizedString(
            "mouseButtonBindingHint", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Release the controller, then press the button that should click the mouse.",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var restoreDefaults: String {
        NSLocalizedString(
            "restoreDefaults", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Restore Defaults",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var returnLabel: String {
        NSLocalizedString(
            "returnLabel", tableName: "ControllerConfiguration", bundle: bundle, value: "Return",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var right: String {
        NSLocalizedString(
            "right", tableName: "ControllerConfiguration", bundle: bundle, value: "Right",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var rightAnalogStick: String {
        NSLocalizedString(
            "rightAnalogStick", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Right analog stick",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var rightArrow: String {
        NSLocalizedString(
            "rightArrow", tableName: "ControllerConfiguration", bundle: bundle, value: "Right arrow",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var rightShoulder: String {
        NSLocalizedString(
            "rightShoulder", tableName: "ControllerConfiguration", bundle: bundle, value: "Right shoulder",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    func rightStick(direction: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "rightStick", tableName: "ControllerConfiguration", bundle: bundle, value: "Right stick %1$@",
                comment:
                    "ControllerConfiguration: Formatted message. direction: runtime text; keep its placeholder"
            ),
            direction)
    }

    var rightTrigger: String {
        NSLocalizedString(
            "rightTrigger", tableName: "ControllerConfiguration", bundle: bundle, value: "Right trigger",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var controllerSelectionHint: String {
        NSLocalizedString(
            "controllerSelectionHint", tableName: "ControllerConfiguration", bundle: bundle,
            value: "Select a controller for this running player. Automatic is restored on the next launch.",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var shift: String {
        NSLocalizedString(
            "shift", tableName: "ControllerConfiguration", bundle: bundle, value: "Shift",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var space: String {
        NSLocalizedString(
            "space", tableName: "ControllerConfiguration", bundle: bundle, value: "Space",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var tab: String {
        NSLocalizedString(
            "tab", tableName: "ControllerConfiguration", bundle: bundle, value: "Tab",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var up: String {
        NSLocalizedString(
            "up", tableName: "ControllerConfiguration", bundle: bundle, value: "Up",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var upArrow: String {
        NSLocalizedString(
            "upArrow", tableName: "ControllerConfiguration", bundle: bundle, value: "Up arrow",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var upperLeft: String {
        NSLocalizedString(
            "upperLeft", tableName: "ControllerConfiguration", bundle: bundle, value: "Upper left",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }

    var upperRight: String {
        NSLocalizedString(
            "upperRight", tableName: "ControllerConfiguration", bundle: bundle, value: "Upper right",
            comment: "ControllerConfiguration: User-visible label, instruction, or error message.")
    }
}
