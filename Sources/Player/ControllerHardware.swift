import Foundation

/// Native controller discovery and emulator input. Access only from the main thread.
enum ControllerHardware {
    static func initialize() {
        a2_hid_gamepad_init()
    }

    static var count: Int32 {
        return a2_hid_gamepad_count()
    }

    static func name(at index: Int32) -> String {
        return String(cString: a2_hid_gamepad_name_at(index))
    }

    static func identifier(at index: Int32) -> UInt64 {
        return a2_hid_gamepad_id(index)
    }

    /// A disconnected identifier clears selection rather than choosing a different device.
    static func select(_ identifier: UInt64) -> Bool {
        return a2_hid_gamepad_select(identifier) != 0
    }

    static func value(at index: Int32) -> Float {
        return a2_hid_gamepad_value(index)
    }

    static func hasButton(at index: Int) -> Bool {
        return a2_hid_gamepad_has_button(Int32(index)) != 0
    }

    static func setJoystickMode(_ mode: Int32) {
        joystick_callback_init(mode)
    }

    static func updateJoystick(buttons: UInt32, x: Int32, y: Int32) {
        joystick_callback_update(buttons, x, y)
    }

    static func refreshButtons() {
        joystick_update_buttons()
    }
}
