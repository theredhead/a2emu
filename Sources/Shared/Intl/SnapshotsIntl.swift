import Foundation

/// Localized text for Snapshots; resource lookup and formatting stay out of the UI code.
final class SnapshotsIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func recoveryFailure(recoveryPath: String, errorDescription: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "recoveryFailure", tableName: "Snapshots", bundle: bundle,
                value:
                    "Could not restore the snapshot or recover the previous machine. The emulator is paused. Recovery data: %1$@. %2$@",
                comment:
                    "Snapshots: Formatted message. recoveryPath: runtime text; keep its placeholder; errorDescription: runtime text; keep its placeholder"
            ),
            recoveryPath, errorDescription)
    }

    var startTheEmulatorBeforeSavingA: String {
        NSLocalizedString(
            "startTheEmulatorBeforeSavingA", tableName: "Snapshots", bundle: bundle,
            value: "Start the emulator before saving a snapshot.",
            comment: "Snapshots: User-visible label, instruction, or error message.")
    }

    var thisSnapshotBelongsToAPlayer: String {
        NSLocalizedString(
            "thisSnapshotBelongsToAPlayer", tableName: "Snapshots", bundle: bundle,
            value: "This snapshot belongs to a player with a different set of disks.",
            comment: "Snapshots: User-visible label, instruction, or error message.")
    }

    var thisSnapshotHasAMountedDisk: String {
        NSLocalizedString(
            "thisSnapshotHasAMountedDisk", tableName: "Snapshots", bundle: bundle,
            value: "This snapshot has a mounted disk that is not part of this player.",
            comment: "Snapshots: User-visible label, instruction, or error message.")
    }
}
