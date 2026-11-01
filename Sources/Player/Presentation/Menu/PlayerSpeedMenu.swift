import Cocoa

private let playerIntl = PlayerIntl()

/// Owns dynamic speed-menu items and remembers discovered accelerator speeds for one menu session.
/// It renders supplied values and emits actions; it never reads or changes emulator state.
final class PlayerSpeedMenu {
    var speedMenuItems: [NSMenuItem] = []
    private var customSpeedItems: [Int32: NSMenuItem] = [:]
    private var unknownSpeedItem: NSMenuItem?

    func reset() {
        speedMenuItems = []
        customSpeedItems = [:]
        unknownSpeedItem = nil
    }

    func configure(in layout: PlayerMenu) {
        guard let menu = layout.submenu(.speed) else { return }
        layout.replaceContents(of: .speed, with: PlayerMenuLayout.speeds)
        menu.showsStateColumn = true
        speedMenuItems = menu.items
        customSpeedItems = [:]
        unknownSpeedItem = nil
    }

    func refresh(speedLimit: Int32, acceleratorSpeedMHz: Int32, target: AnyObject, action: Selector) {
        let knownLimit = EmulationSpeed(rawValue: Int(speedLimit))
        let customZip = knownLimit == .eightMHz && acceleratorSpeedMHz != 8
        guard let menu = speedMenuItems.first?.menu else { return }
        if customZip, acceleratorSpeedMHz > 0,
            customSpeedItems[acceleratorSpeedMHz] == nil
        {
            let item = NSMenuItem(
                title: playerIntl.mhz(megahertz: Int(acceleratorSpeedMHz)),
                action: action,
                keyEquivalent: "")
            item.target = target
            item.representedObject = [
                Int(EmulationSpeed.eightMHz.rawValue), Int(acceleratorSpeedMHz),
            ]
            // Keep discovered speeds ordered, immediately before Unlimited.
            let higher = customSpeedItems.keys.filter { $0 > acceleratorSpeedMHz }.min()
            let next =
                higher.flatMap { customSpeedItems[$0] }
                ?? speedMenuItems.first { $0.tag == EmulationSpeed.unlimited.rawValue }
            menu.insertItem(item, at: next.map { menu.index(of: $0) } ?? menu.numberOfItems)
            customSpeedItems[acceleratorSpeedMHz] = item
        }

        let unknown = knownLimit == nil || (customZip && acceleratorSpeedMHz <= 0)
        if unknown {
            if unknownSpeedItem == nil {
                let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.insertItem(item, at: 0)
                unknownSpeedItem = item
            }
            unknownSpeedItem?.title =
                knownLimit == nil
                ? playerIntl.customSpeedMode(mode: Int(speedLimit))
                : playerIntl.mhzInvalidSetting(megahertz: Int(acceleratorSpeedMHz))
            unknownSpeedItem?.state = .on
        } else if let item = unknownSpeedItem {
            menu.removeItem(item)
            unknownSpeedItem = nil
        }
        for (mhz, item) in customSpeedItems {
            item.state = customZip && acceleratorSpeedMHz == mhz ? .on : .off
        }
        for item in speedMenuItems {
            item.state = item.tag == Int(speedLimit) && !customZip ? .on : .off
        }
    }
}
