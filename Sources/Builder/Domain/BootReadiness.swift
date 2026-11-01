import Foundation

/// Evidence from disk contents, rather than an assurance that arbitrary software will run successfully.
enum DiskBootability {
    case bootable
    case notBootable
    case unknown
}
/// Startup policy for the selected slot's first drive, independent of controls and filesystem inspection.
enum BootReadiness {
    case ready
    case missingDisk
    case notBootable
    case unknown
    case snapshot

    static func evaluate(
        disks: [URL], bootSlot: Int?, drives: [DriveAddress], mounts: [DiskMount],
        restoresSnapshot: Bool, inspect: (URL, Int) -> DiskBootability
    ) -> BootReadiness {
        if restoresSnapshot { return .snapshot }
        guard let bootSlot = bootSlot else { return .missingDisk }

        let first = DriveAddress(slot: bootSlot, drive: 0)
        let candidates = mounts.filter { $0.address == first }
        guard drives.contains(first), !candidates.isEmpty else { return .missingDisk }
        guard candidates.count == 1, disks.indices.contains(candidates[0].diskIndex) else { return .unknown }
        switch inspect(disks[candidates[0].diskIndex], bootSlot) {
        case .bootable: return .ready
        case .notBootable: return .notBootable
        case .unknown: return .unknown
        }
    }
}
