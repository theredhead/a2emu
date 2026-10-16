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
