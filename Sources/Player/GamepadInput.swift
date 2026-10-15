import Cocoa
import GameController

/// Bridges GameController or HID input to the emulator; create and poll on the main thread.
final class GamepadInput {
    private var controller: GCController?
    private var connected = false
    private let hidSnapshot = GCController.withExtendedGamepad()
    private var pressedKeys = Set<Int32>()
    var mapping = ControllerMapping.load()

    init() {
        GCController.shouldMonitorBackgroundEvents = false
        a2_hid_gamepad_init()
    }

    var controllerName: String {
        controller?.vendorName
            ?? (a2_hid_gamepad_connected() != 0 ? String(cString: a2_hid_gamepad_name()) : nil)
            ?? (connected ? "Game controller connected" : "No game controller connected")
    }

    /// Polls input and releases held controls when inactive or disconnected.
    /// The key callback receives true for key-up and false for key-down.
    func update(active: Bool, keyEvent: ((Int32, Bool) -> Void)? = nil) {
        let available = GCController.controllers().filter { $0.extendedGamepad != nil }
        if controller == nil || !available.contains(where: { $0 === controller }) {
            controller = available.first
        }

        var profile = controller?.extendedGamepad
        if profile == nil, a2_hid_gamepad_connected() != 0, let snapshot = hidSnapshot.extendedGamepad {
            snapshot.leftThumbstick.setValueForXAxis(a2_hid_gamepad_value(0), yAxis: a2_hid_gamepad_value(1))
            snapshot.rightThumbstick.setValueForXAxis(a2_hid_gamepad_value(2), yAxis: a2_hid_gamepad_value(3))
            snapshot.dpad.setValueForXAxis(a2_hid_gamepad_value(4), yAxis: a2_hid_gamepad_value(5))
            for index in 0..<8 {
                mapping.button(index, on: snapshot).setValue(a2_hid_gamepad_value(Int32(index + 6)))
            }
            profile = snapshot
        }
        guard let pad = profile else {
            sendKeys([], event: keyEvent)
            if connected {
                joystick_callback_update(0, 0, 0)
                joystick_update_buttons()
            }
            joystick_callback_init(-1)
            connected = false
            return
        }
        joystick_callback_init(1)
        connected = true
        guard active else {
            sendKeys([], event: keyEvent)
            joystick_callback_update(0, 0, 0)
            joystick_update_buttons()
            return
        }

        let state = Self.state(for: pad, mapping: mapping)
        if mapping.keyboardMode == true {
            var keys = Set<Int32>()
            let codes = mapping.keyCodes ?? ControllerMapping.defaultKeyCodes
            if state.x < -16000 {
                keys.insert(Int32(codes[0]))
            }
            if state.x > 16000 {
                keys.insert(Int32(codes[1]))
            }
            if state.y < -16000 {
                keys.insert(Int32(codes[2]))
            }
            if state.y > 16000 {
                keys.insert(Int32(codes[3]))
            }
            if state.buttons & 1 != 0 {
                keys.insert(Int32(codes[4]))
            }
            if state.buttons & 2 != 0 {
                keys.insert(Int32(codes[5]))
            }
            sendKeys(keys, event: keyEvent)
            joystick_callback_update(0, 0, 0)
        } else {
            sendKeys([], event: keyEvent)
            joystick_callback_update(state.buttons, state.x, state.y)
        }
    }

    private func sendKeys(_ keys: Set<Int32>, event: ((Int32, Bool) -> Void)?) {
        for key in pressedKeys.subtracting(keys) {
            event?(key, true)
        }
        for key in keys.subtracting(pressedKeys) {
            event?(key, false)
        }
        pressedKeys = keys
    }

    static func state(for pad: GCExtendedGamepad, mapping: ControllerMapping = ControllerMapping()) -> (
        buttons: UInt32, x: Int32, y: Int32
    ) {
        let dpad = pad.dpad
        let useDpad =
            mapping.movement == 2
            || (mapping.movement == 0 && (abs(dpad.xAxis.value) > 0.1 || abs(dpad.yAxis.value) > 0.1))
        let stick = useDpad ? dpad : (mapping.movement == 1 ? pad.rightThumbstick : pad.leftThumbstick)
        let centered = hypot(stick.xAxis.value, stick.yAxis.value) < mapping.deadZone
        let x = centered ? 0 : axis(stick.xAxis.value * (mapping.invertX ? -1 : 1))
        // GameController’s positive Y points up; Apple II paddle Y points down.
        let y = centered ? 0 : axis(stick.yAxis.value * (mapping.invertY ? 1 : -1))
        var buttons: UInt32 = 0
        if mapping.button(mapping.button0, on: pad).isPressed {
            buttons |= 1
        }
        if mapping.button(mapping.button1, on: pad).isPressed {
            buttons |= 2
        }
        return (buttons, x, y)
    }

    private static func axis(_ value: Float) -> Int32 {
        let value = min(1, max(-1, value))
        return Int32((value * 32767).rounded())
    }
}
