import Cocoa
import GameController

/// Bridges GameController or HID input to the emulator; create and poll on the main thread.
final class GamepadInput {
    private var nativeControllers: [GCController] = []
    private var nativeIDs: [ObjectIdentifier: String] = [:]
    private var automaticControllerID: String?
    private var lastInputID: String?

    /// Runtime connection choice; nil follows the automatic selection. Names are never used as IDs.
    var selectedControllerID: String?
    var controllerDisconnected: (() -> Void)?
    private var connected = false
    private let hidSnapshot = GCController.withExtendedGamepad()
    private var pressedKeys = Set<Int32>()
    var mapping = ControllerMapping.load()

    init() {
        GCController.shouldMonitorBackgroundEvents = false
        ControllerHardware.initialize()
    }

    var controllerName: String {
        let choices = availableControllers()
        return selectedChoice(in: choices, requestedID: selectedControllerID)?.name
            ?? (selectedControllerID == nil
                ? "No game controller connected" : "Selected controller disconnected")
    }

    /// Lists every supported native and direct-input connection with stable session IDs.
    func availableControllers() -> [ControllerChoice] {
        let available = GCController.controllers().filter { $0.extendedGamepad != nil }
        let ordered =
            nativeControllers.filter { old in available.contains { $0 === old } }
            + available.filter { new in !nativeControllers.contains { $0 === new } }
        nativeIDs = nativeIDs.filter { id, _ in ordered.contains { ObjectIdentifier($0) == id } }
        nativeControllers = ordered
        var choices: [ControllerChoice] = []
        for controller in ordered {
            let identifier = ObjectIdentifier(controller)
            if nativeIDs[identifier] == nil { nativeIDs[identifier] = "gc:" + UUID().uuidString }
            choices.append(
                ControllerChoice(id: nativeIDs[identifier]!, name: controller.vendorName ?? "Game controller")
            )
        }
        let nativeNames = Set(choices.map { $0.name })
        for index in 0..<ControllerHardware.count {
            let name = ControllerHardware.name(at: index)
            // Some devices expose both connections. Keep direct input available as a fallback.
            let label = nativeNames.contains(name) ? "\(name) (direct input)" : name
            choices.append(
                ControllerChoice(id: "hid:\(ControllerHardware.identifier(at: index))", name: label))
        }
        let counts = Dictionary(grouping: choices, by: { $0.name }).mapValues { $0.count }
        var occurrences: [String: Int] = [:]
        return choices.map { choice in
            occurrences[choice.name, default: 0] += 1
            let name =
                counts[choice.name, default: 0] > 1
                ? "\(choice.name) (\(occurrences[choice.name]!))" : choice.name
            return ControllerChoice(id: choice.id, name: name)
        }
    }

    private func selectedChoice(in choices: [ControllerChoice], requestedID: String?) -> ControllerChoice? {
        if let requestedID = requestedID { return choices.first { $0.id == requestedID } }
        if let existing = choices.first(where: { $0.id == automaticControllerID }) { return existing }
        automaticControllerID = choices.first?.id
        return choices.first
    }

    /// Polls input and releases held controls when inactive or disconnected.
    /// The key callback receives true for key-up and false for key-down.
    func update(active: Bool, keyEvent: ((Int32, Bool) -> Void)? = nil) {
        let input = currentProfile(controllerID: selectedControllerID)
        var interrupted = false
        if input?.id != lastInputID {
            if let previous = lastInputID, !availableControllers().contains(where: { $0.id == previous }) {
                interrupted = true
                controllerDisconnected?()
            }
            sendKeys([], event: keyEvent)
            lastInputID = input?.id
        }
        guard let pad = input?.pad else {
            sendKeys([], event: keyEvent)
            if connected {
                ControllerHardware.updateJoystick(buttons: 0, x: 0, y: 0)
                ControllerHardware.refreshButtons()
            }
            ControllerHardware.setJoystickMode(-1)
            connected = false
            return
        }
        ControllerHardware.setJoystickMode(1)
        connected = true
        guard active && !interrupted else {
            sendKeys([], event: keyEvent)
            ControllerHardware.updateJoystick(buttons: 0, x: 0, y: 0)
            ControllerHardware.refreshButtons()
            return
        }

        let state = Self.state(for: pad, mapping: mapping)
        if mapping.keyboardMode == true {
            let keys = keyboardKeys(for: pad, mapping: mapping, state: state)
            sendKeys(keys, event: keyEvent)
            ControllerHardware.updateJoystick(buttons: 0, x: 0, y: 0)
        } else {
            sendKeys([], event: keyEvent)
            ControllerHardware.updateJoystick(buttons: state.buttons, x: state.x, y: state.y)
        }
    }

    /// Reads the same controller sources as emulation without sending events to the C core.
    func previewState(mapping: ControllerMapping, controllerID: String?) -> (
        buttons: UInt32, x: Int32, y: Int32, keys: Set<Int32>
    )? {
        guard let pad = currentProfile(controllerID: controllerID)?.pad else { return nil }
        let state = Self.state(for: pad, mapping: mapping)
        return (state.buttons, state.x, state.y, keyboardKeys(for: pad, mapping: mapping, state: state))
    }

    private func currentProfile(controllerID: String?) -> (id: String, pad: GCExtendedGamepad)? {
        let choices = availableControllers()
        guard let choice = selectedChoice(in: choices, requestedID: controllerID) else { return nil }
        if choice.id.hasPrefix("gc:") {
            guard
                let controller = nativeControllers.first(where: {
                    nativeIDs[ObjectIdentifier($0)] == choice.id
                }),
                let pad = controller.extendedGamepad
            else { return nil }
            return (choice.id, pad)
        }
        guard let identifier = UInt64(choice.id.dropFirst(4)), ControllerHardware.select(identifier),
            let snapshot = hidSnapshot.extendedGamepad
        else { return nil }
        snapshot.leftThumbstick.setValueForXAxis(
            ControllerHardware.value(at: 0), yAxis: ControllerHardware.value(at: 1))
        snapshot.rightThumbstick.setValueForXAxis(
            ControllerHardware.value(at: 2), yAxis: ControllerHardware.value(at: 3))
        snapshot.dpad.setValueForXAxis(
            ControllerHardware.value(at: 4), yAxis: ControllerHardware.value(at: 5))
        for index in 0..<8 {
            mapping.button(index, on: snapshot).setValue(ControllerHardware.value(at: Int32(index + 6)))
        }
        return (choice.id, snapshot)
    }

    private func keyboardKeys(
        for pad: GCExtendedGamepad, mapping: ControllerMapping,
        state: (buttons: UInt32, x: Int32, y: Int32)
    ) -> Set<Int32> {
        var physicalButtons: UInt32 = 0
        for index in 0..<8 where mapping.button(index, on: pad).isPressed {
            physicalButtons |= 1 << index
        }
        return mapping.keyboardKeys(
            x: state.x, y: state.y, buttons: state.buttons, physicalButtons: physicalButtons)
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
