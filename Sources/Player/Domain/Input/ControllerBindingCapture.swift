import Foundation

/// Requires a neutral sample after selecting a key so an already-held control cannot bind accidentally.
struct ControllerBindingCapture {
    private(set) var armed = false
    private var waitingForNeutral = true

    mutating func begin() {
        armed = true
        waitingForNeutral = true
    }

    mutating func cancel() { armed = false }

    mutating func consume(_ inputs: Set<Int>) -> Int? {
        guard armed else { return nil }
        if inputs.isEmpty {
            waitingForNeutral = false
            return nil
        }
        guard !waitingForNeutral, inputs.count == 1 else { return nil }
        armed = false
        return inputs.first
    }
}
