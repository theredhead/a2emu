import Foundation

/// Combines manual pause intent with independently owned dialog pauses; releasing one cannot resume another.
struct EmulationPause {
    private(set) var manuallyPaused = false
    private(set) var manualReason: String?
    private(set) var dialogs = Set<String>()

    var isPaused: Bool { return manuallyPaused || !dialogs.isEmpty }

    var reason: String? { return manualReason ?? dialogs.sorted().first }

    var canToggleManualPause: Bool { return dialogs.isEmpty }

    mutating func setManual(_ paused: Bool, reason: String?) {
        if paused != manuallyPaused || reason != nil { manualReason = paused ? reason : nil }
        manuallyPaused = paused
    }

    mutating func setDialog(_ open: Bool, reason: String) {
        if open { dialogs.insert(reason) } else { dialogs.remove(reason) }
    }
}
