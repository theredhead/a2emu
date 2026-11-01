import Foundation

private let controllerConfigurationIntl = ControllerConfigurationIntl()

/// Localized editor choices are presentation metadata; the binding model validates numeric codes independently.
extension ControllerMapping {
    static let keyChoices: [(String, Int)] = [
        (controllerConfigurationIntl.keypad7, 89), (controllerConfigurationIntl.keypad9, 92),
        (controllerConfigurationIntl.keypad1, 83), (controllerConfigurationIntl.keypad3, 85),
        (controllerConfigurationIntl.keypad0, 82), (controllerConfigurationIntl.keypadDecimal, 65),
        (controllerConfigurationIntl.keypadEnter, 76), (controllerConfigurationIntl.keypadClear, 71),
        (controllerConfigurationIntl.keypadEquals, 81), (controllerConfigurationIntl.keypadDivide, 75),
        (controllerConfigurationIntl.keypadMultiply, 67), (controllerConfigurationIntl.keypadMinus, 78),
        (controllerConfigurationIntl.keypadPlus, 69),
        (controllerConfigurationIntl.keypad4, 86), (controllerConfigurationIntl.keypad6, 88),
        (controllerConfigurationIntl.keypad8, 91), (controllerConfigurationIntl.keypad5, 87),
        (controllerConfigurationIntl.keypad2, 84),
        (controllerConfigurationIntl.commandOpenApple, 55),
        (controllerConfigurationIntl.optionClosedApple, 58), (controllerConfigurationIntl.leftArrow, 123),
        (controllerConfigurationIntl.rightArrow, 124), (controllerConfigurationIntl.upArrow, 126),
        (controllerConfigurationIntl.downArrow, 125), (controllerConfigurationIntl.space, 49),
        (controllerConfigurationIntl.returnLabel, 36), ("A", 0),
        ("B", 11), ("C", 8), ("D", 2), ("E", 14), ("F", 3), ("G", 5), ("H", 4),
        ("I", 34), ("J", 38), ("K", 40), ("L", 37), ("M", 46), ("N", 45), ("O", 31),
        ("P", 35), ("Q", 12), ("R", 15), ("S", 1), ("T", 17), ("U", 32), ("V", 9),
        ("W", 13), ("X", 7), ("Y", 16), ("Z", 6),
        ("0", 29), ("1", 18), ("2", 19), ("3", 20), ("4", 21), ("5", 23), ("6", 22),
        ("7", 26), ("8", 28), ("9", 25),
        ("-", 27), ("=", 24), ("[", 33), ("]", 30), (";", 41), ("'", 39),
        (",", 43), (".", 47), ("/", 44), (controllerConfigurationIntl.backslash, 42),
        (controllerConfigurationIntl.backtick, 50),
        (controllerConfigurationIntl.capsLock, 57), (controllerConfigurationIntl.escape, 53),
        (controllerConfigurationIntl.tab, 48), (controllerConfigurationIntl.delete, 51),
        (controllerConfigurationIntl.shift, 56), (controllerConfigurationIntl.control, 59),
    ]

    static let buttonNames = [
        "A", "B", "X", "Y", controllerConfigurationIntl.leftShoulder,
        controllerConfigurationIntl.rightShoulder, controllerConfigurationIntl.leftTrigger,
        controllerConfigurationIntl.rightTrigger,
        controllerConfigurationIntl.menuStart, controllerConfigurationIntl.optionsSelect,
    ]

    static let movementNames = [
        controllerConfigurationIntl.leftAnalogStickDPad, controllerConfigurationIntl.rightAnalogStick,
        controllerConfigurationIntl.dPad,
    ]
}
