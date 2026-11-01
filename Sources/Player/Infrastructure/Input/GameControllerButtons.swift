import GameController

extension ControllerMapping {
    func button(_ index: Int, on pad: GCExtendedGamepad) -> GCControllerButtonInput? {
        [
            pad.buttonA, pad.buttonB, pad.buttonX, pad.buttonY, pad.leftShoulder, pad.rightShoulder,
            pad.leftTrigger, pad.rightTrigger, pad.buttonMenu, pad.buttonOptions,
        ][index]
    }
}
