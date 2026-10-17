import Foundation

/// Localized text for PlayerSnapshot; resource lookup and formatting stay out of the UI code.
final class PlayerSnapshotIntl {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var invalidMetadata: String {
        NSLocalizedString(
            "invalidMetadata", tableName: "PlayerSnapshot", bundle: bundle,
            value: "The snapshot metadata is invalid or uses an unsupported format.",
            comment: "PlayerSnapshot: User-visible label, instruction, or error message.")
    }

    var snapshotsMustContainTheirOwnDisk: String {
        NSLocalizedString(
            "snapshotsMustContainTheirOwnDisk", tableName: "PlayerSnapshot", bundle: bundle,
            value: "Snapshots must contain their own disk directory, without symbolic links.",
            comment: "PlayerSnapshot: User-visible label, instruction, or error message.")
    }

    var theCompressedSnapshotMetadataIsInvalid: String {
        NSLocalizedString(
            "theCompressedSnapshotMetadataIsInvalid", tableName: "PlayerSnapshot", bundle: bundle,
            value: "The compressed snapshot metadata is invalid.",
            comment: "PlayerSnapshot: User-visible label, instruction, or error message.")
    }

    func theCompressedSnapshotPayloadIsDamaged(name: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "theCompressedSnapshotPayloadIsDamaged", tableName: "PlayerSnapshot", bundle: bundle,
                value: "The compressed snapshot payload is damaged: %1$@.",
                comment: "PlayerSnapshot: Formatted message. name: runtime text; keep its placeholder"),
            name)
    }

    var theCompressedSnapshotPayloadIsInvalid: String {
        NSLocalizedString(
            "theCompressedSnapshotPayloadIsInvalid", tableName: "PlayerSnapshot", bundle: bundle,
            value: "The compressed snapshot payload is invalid.",
            comment: "PlayerSnapshot: User-visible label, instruction, or error message.")
    }

    var theExpandedSnapshotPayloadIsToo: String {
        NSLocalizedString(
            "theExpandedSnapshotPayloadIsToo", tableName: "PlayerSnapshot", bundle: bundle,
            value: "The expanded snapshot payload is too large.",
            comment: "PlayerSnapshot: User-visible label, instruction, or error message.")
    }

    var theSnapshotHeaderIsIncomplete: String {
        NSLocalizedString(
            "theSnapshotHeaderIsIncomplete", tableName: "PlayerSnapshot", bundle: bundle,
            value: "The snapshot header is incomplete.",
            comment: "PlayerSnapshot: User-visible label, instruction, or error message.")
    }

    func theSnapshotIsIncompleteOrDamaged(name: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "theSnapshotIsIncompleteOrDamaged", tableName: "PlayerSnapshot", bundle: bundle,
                value: "The snapshot is incomplete or damaged: %1$@.",
                comment: "PlayerSnapshot: Formatted message. name: runtime text; keep its placeholder"),
            name)
    }

    var theSnapshotMetadataIsTooLarge: String {
        NSLocalizedString(
            "theSnapshotMetadataIsTooLarge", tableName: "PlayerSnapshot", bundle: bundle,
            value: "The snapshot metadata is too large.",
            comment: "PlayerSnapshot: User-visible label, instruction, or error message.")
    }

    var theSnapshotMetadataMustBeAn: String {
        NSLocalizedString(
            "theSnapshotMetadataMustBeAn", tableName: "PlayerSnapshot", bundle: bundle,
            value: "The snapshot metadata must be an ordinary file.",
            comment: "PlayerSnapshot: User-visible label, instruction, or error message.")
    }

    var thisSnapshotUsesAnUnsupportedRam: String {
        NSLocalizedString(
            "thisSnapshotUsesAnUnsupportedRam", tableName: "PlayerSnapshot", bundle: bundle,
            value: "This snapshot uses an unsupported RAM configuration.",
            comment: "PlayerSnapshot: User-visible label, instruction, or error message.")
    }

    var thisSnapshotWasSavedByA: String {
        NSLocalizedString(
            "thisSnapshotWasSavedByA", tableName: "PlayerSnapshot", bundle: bundle,
            value:
                "This snapshot was saved by a different emulator build. Capture a new one with this player version.",
            comment: "PlayerSnapshot: User-visible label, instruction, or error message.")
    }
}
