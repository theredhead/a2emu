import Cocoa
import GameController
import ObjectiveC

@_silgen_name("fixture_set_hid_count") func setHIDCount(_ count: Int32)
@_silgen_name("fixture_last_x") func lastX() -> Int32
private var fixtureControllers: [GCController] = []
extension GCController {
    @objc class func fixtureAvailableControllers() -> [GCController] { return fixtureControllers }
}

@main struct ControllerSelectionTests {
    static func main() {
        let original = class_getClassMethod(GCController.self, NSSelectorFromString("controllers"))!
        let replacement = class_getClassMethod(
            GCController.self, #selector(GCController.fixtureAvailableControllers))!
        method_exchangeImplementations(original, replacement)
        defer { method_exchangeImplementations(original, replacement) }
        let first = GCController.withExtendedGamepad()
        let second = GCController.withExtendedGamepad()
        first.extendedGamepad!.leftThumbstick.setValueForXAxis(-1, yAxis: 0)
        second.extendedGamepad!.leftThumbstick.setValueForXAxis(1, yAxis: 0)
        fixtureControllers = [first, second]
        let input = GamepadInput()
        let choices = input.availableControllers()
        precondition(choices.count == 4 && Set(choices.map { $0.id }).count == 4)
        precondition(choices[0].name != choices[1].name, "Identical models need distinct labels")
        precondition(input.availableControllers() == choices, "Refreshing must retain connection IDs")
        let mapping = ControllerMapping()
        precondition(input.previewState(mapping: mapping, controllerID: choices[0].id)!.x < 0)
        precondition(input.previewState(mapping: mapping, controllerID: choices[1].id)!.x > 0)
        precondition(input.previewState(mapping: mapping, controllerID: "hid:100")!.x < 0)
        precondition(input.previewState(mapping: mapping, controllerID: "hid:101")!.x > 0)
        precondition(input.supportedButtonIndices(controllerID: choices[0].id)!.contains(8))
        precondition(input.supportedButtonIndices(controllerID: "hid:100") == Set(0..<8))
        let pad = first.extendedGamepad!
        precondition(input.supportedButtonIndices(controllerID: choices[0].id)!.contains(9) == (pad.buttonOptions != nil))
        input.selectedControllerID = choices[0].id
        input.mapping.keyboardMode = true
        input.mapping.keyboardButtonKeyCodes = [-1, -1, -1, -1, -1, -1, -1, -1, 36, 53]
        pad.leftThumbstick.setValueForXAxis(0, yAxis: 0)
        pad.buttonMenu.setValue(1)
        var events: [(Int32, Bool)] = []
        input.update(active: true) { events.append(($0, $1)) }
        precondition(events.count == 1 && events[0].0 == 36 && !events[0].1)
        events = []
        input.update(active: true) { events.append(($0, $1)) }
        precondition(events.isEmpty, "Holding Menu must not repeat key-down events")
        pad.buttonMenu.setValue(0)
        input.update(active: true) { events.append(($0, $1)) }
        precondition(events.count == 1 && events[0].0 == 36 && events[0].1)
        if let options = pad.buttonOptions {
            events = []
            options.setValue(1)
            input.update(active: true) { events.append(($0, $1)) }
            precondition(events.count == 1 && events[0].0 == 53 && !events[0].1)
            input.update(active: false) { events.append(($0, $1)) }
            precondition(events.count == 2 && events[1].0 == 53 && events[1].1)
            options.setValue(0)
        }
        input.mapping.keyboardLayout = true
        input.mapping.prepareKeyboardBindings()
        input.mapping.keyboardStickKeys = [0, 2, 13, 1, -1, -1, -1, -1, 123, 124, 126, 125, -1, -1, -1, -1]
        input.mapping.keyboardDpadAxisOwners = [-1, -1]
        input.mapping.keyboardDpadKeys = Array(repeating: -1, count: 8)
        pad.rightThumbstick.setValueForXAxis(1, yAxis: 0)
        let rightPreview = input.previewState(mapping: input.mapping, controllerID: choices[0].id)!
        precondition(rightPreview.inputs == [19] && rightPreview.keys == [124])
        pad.leftThumbstick.setValueForXAxis(-1, yAxis: 0)
        let bothPreview = input.previewState(mapping: input.mapping, controllerID: choices[0].id)!
        precondition(bothPreview.inputs == [0, 19] && bothPreview.keys == [0, 124])
        pad.rightThumbstick.setValueForXAxis(0, yAxis: 0)
        print("PASS full keyboard preview distinguishes both sticks and sends their independent keys")
        var mouseTime: TimeInterval = 100
        var mouseEvents: [(Int32, Int32, Bool?)] = []
        input.mouseClock = { mouseTime }
        input.mouseEvent = { mouseEvents.append(($0, $1, $2)) }
        input.mapping.mouseMovementSource = 1
        input.mapping.mouseButtonInputs = [8]
        pad.rightThumbstick.setValueForXAxis(1, yAxis: 0)
        pad.buttonMenu.setValue(1)
        input.update(active: true)
        precondition(mouseEvents.count == 1 && mouseEvents[0].2 == true)
        mouseTime += 0.01
        input.update(active: true)
        precondition(mouseEvents.last!.0 > 0 && mouseEvents.last!.1 == 0)
        input.update(active: false)
        precondition(mouseEvents.last!.2 == false, "Pausing must release the mouse button")
        let pausedCount = mouseEvents.count
        mouseTime = 200
        input.update(active: false)
        precondition(mouseEvents.count == pausedCount)
        input.update(active: true)
        precondition(mouseEvents.last!.0 == 0 && mouseEvents.last!.2 == true, "Resuming must not accumulate mouse movement")
        pad.buttonMenu.setValue(0)
        pad.rightThumbstick.setValueForXAxis(0, yAxis: 0)
        input.update(active: true)
        precondition(mouseEvents.last!.2 == false)
        pad.buttonMenu.setValue(1)
        input.update(active: true)
        precondition(mouseEvents.last!.2 == true)
        fixtureControllers = [second]
        input.update(active: true)
        precondition(mouseEvents.last!.2 == false, "Disconnecting a controller must release its mouse click")
        pad.buttonMenu.setValue(0)
        fixtureControllers = [first, second]
        print("PASS controller mouse movement, press/release, disconnect release and pause-safe timing")
        input.mapping = ControllerMapping()
        pad.leftThumbstick.setValueForXAxis(-1, yAxis: 0)
        print("PASS Menu / Start key press/release and optional Options / Select availability")
        var disconnects = 0
        input.controllerDisconnected = { disconnects += 1 }
        input.selectedControllerID = choices[1].id
        input.update(active: true)
        precondition(lastX() > 0)
        fixtureControllers = [first]
        input.update(active: true)
        precondition(disconnects == 1 && lastX() == 0)
        input.update(active: true)
        precondition(disconnects == 1, "A missing device should report one disconnect")
        input.selectedControllerID = "hid:101"
        input.update(active: true)
        precondition(lastX() > 0)
        setHIDCount(1)
        input.update(active: true)
        precondition(disconnects == 2 && lastX() == 0)
        input.selectedControllerID = nil
        input.update(active: true)
        fixtureControllers = []
        input.update(active: true)
        precondition(
            disconnects == 3 && lastX() == 0,
            "Automatic fallback must still report the lost active controller")
        print("PASS native/direct controller routing, identical names, switching, and disconnect handling")
    }
}
