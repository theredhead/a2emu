import Cocoa

/// Owns disk-choice menu items and their selection/compatibility display; storage and mounts are supplied values.
final class PlayerDiskMenu {
    var diskMenuItems: [(NSMenuItem, DriveAddress, Int?)] = []

    func reset() { diskMenuItems = [] }

    func configure(in layout: PlayerMenu, manifest: PlayerManifest, canSave: @escaping () -> Bool) -> Bool {
        let visible = manifest.drives.count > 1 || manifest.diskFiles.count > 1
        layout.replaceContents(
            of: .disks,
            with: PlayerMenuLayout.savedDisks(canSaveTemporaryMedia: canSave))
        diskMenuItems = []
        guard visible else { return false }

        let contents = PlayerMenuLayout.disks(
            for: manifest, canSaveTemporaryMedia: canSave)
        layout.replaceContents(of: .disks, with: contents.entries)
        for (index, choice) in contents.choices.enumerated() {
            if let item = layout.item(.diskChoice(index)) {
                diskMenuItems.append((item, choice.0, choice.1))
            }
        }
        return true
    }

    func refresh(mountedImages: [DriveAddress: Int], slots: [Int]) {
        for (item, address, index) in diskMenuItems {
            item.state = mountedImages[address] == index ? .on : .off
            if let index = index {
                let mountedElsewhere = mountedImages.contains { $0.key != address && $0.value == index }
                item.isHidden = slots[index] != address.slot || mountedElsewhere
            }
        }
    }
}
