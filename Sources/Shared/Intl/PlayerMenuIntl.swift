import Foundation

/// Localized text for PlayerMenu; resource lookup and formatting stay out of the UI code.
final class PlayerMenuIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func about(appName: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "about", tableName: "PlayerMenu", bundle: bundle, value: "About %1$@",
                comment: "PlayerMenu: Formatted message. appName: runtime text; keep its placeholder"),
            appName)
    }

    var automaticControllerOrKeyboard: String {
        NSLocalizedString(
            "automaticControllerOrKeyboard", tableName: "PlayerMenu", bundle: bundle,
            value: "Automatic (Controller or Keyboard)",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var changeRom: String {
        NSLocalizedString(
            "changeRom", tableName: "PlayerMenu", bundle: bundle, value: "Change ROM…",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var configuration: String {
        NSLocalizedString(
            "configuration", tableName: "PlayerMenu", bundle: bundle, value: "Configuration",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var configurationF4: String {
        NSLocalizedString(
            "configurationF4", tableName: "PlayerMenu", bundle: bundle, value: "Configuration  F4",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var configureControls: String {
        NSLocalizedString(
            "configureControls", tableName: "PlayerMenu", bundle: bundle, value: "Configure Controls…",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var controls: String {
        NSLocalizedString(
            "controls", tableName: "PlayerMenu", bundle: bundle, value: "Controls",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var copyTextScreen: String {
        NSLocalizedString(
            "copyTextScreen", tableName: "PlayerMenu", bundle: bundle, value: "Copy Text Screen",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var disks: String {
        NSLocalizedString(
            "disks", tableName: "PlayerMenu", bundle: bundle, value: "Disks",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var edit: String {
        NSLocalizedString(
            "edit", tableName: "PlayerMenu", bundle: bundle, value: "Edit",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var eject: String {
        NSLocalizedString(
            "eject", tableName: "PlayerMenu", bundle: bundle, value: "Eject",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var emulation: String {
        NSLocalizedString(
            "emulation", tableName: "PlayerMenu", bundle: bundle, value: "Emulation",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var gameController: String {
        NSLocalizedString(
            "gameController", tableName: "PlayerMenu", bundle: bundle, value: "Game Controller",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var keyboardJoystickNumericKeypad: String {
        NSLocalizedString(
            "keyboardJoystickNumericKeypad", tableName: "PlayerMenu", bundle: bundle,
            value: "Keyboard Joystick (Numeric Keypad)",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var mouseJoystick: String {
        NSLocalizedString(
            "mouseJoystick", tableName: "PlayerMenu", bundle: bundle, value: "Mouse Joystick",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var paste: String {
        NSLocalizedString(
            "paste", tableName: "PlayerMenu", bundle: bundle, value: "Paste",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    func quit(appName: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "quit", tableName: "PlayerMenu", bundle: bundle, value: "Quit %1$@",
                comment: "PlayerMenu: Formatted message. appName: runtime text; keep its placeholder"),
            appName)
    }

    var resizeInIntegerMultiples: String {
        NSLocalizedString(
            "resizeInIntegerMultiples", tableName: "PlayerMenu", bundle: bundle,
            value: "Resize in Integer Multiples",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var restartFromDiskWithClearedRam: String {
        NSLocalizedString(
            "restartFromDiskWithClearedRam", tableName: "PlayerMenu", bundle: bundle,
            value: "Restart from disk with cleared RAM; keep disk data and the selected speed.",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var saveScreenshot: String {
        NSLocalizedString(
            "saveScreenshot", tableName: "PlayerMenu", bundle: bundle, value: "Save Screenshot",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var showDebugger: String {
        NSLocalizedString(
            "showDebugger", tableName: "PlayerMenu", bundle: bundle, value: "Show Debugger",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var showSavedDisk: String {
        NSLocalizedString(
            "showSavedDisk", tableName: "PlayerMenu", bundle: bundle, value: "Show Saved Disk",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var speed: String {
        NSLocalizedString(
            "speed", tableName: "PlayerMenu", bundle: bundle, value: "Speed",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var toggleFullScreen: String {
        NSLocalizedString(
            "toggleFullScreen", tableName: "PlayerMenu", bundle: bundle, value: "Toggle Full Screen",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }

    var view: String {
        NSLocalizedString(
            "view", tableName: "PlayerMenu", bundle: bundle, value: "View",
            comment: "PlayerMenu: User-visible label, instruction, or error message.")
    }
}
