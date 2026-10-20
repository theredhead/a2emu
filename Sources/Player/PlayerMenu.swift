import Cocoa

/// Stable identities for runtime updates; menu labels and positions may change freely.
enum PlayerMenuID: Hashable {
    case emulation, configuration, speed, controls, disks, pause, snapshots, integerResize, controllerStatus
    case saveTemporaryMedia
    case diskChoice(Int)
}

/// Native action routing, including commands handled by the focused emulator view.
enum PlayerMenuTarget {
    case delegate, responderChain, application
}

/// Describes layout only. Actions and live emulator state remain in AppDelegate.
indirect enum PlayerMenuEntry {
    case item(Command)
    case separator
    case submenu(
        String, id: PlayerMenuID?, visibleWhen: (() -> Bool)?, enabledWhen: (() -> Bool)?,
        entries: [PlayerMenuEntry])

    struct Command {
        let title: String
        let action: Selector?
        let target: PlayerMenuTarget
        let key: String
        let modifiers: NSEvent.ModifierFlags
        let id: PlayerMenuID?
        let tag: Int
        let toolTip: String?
        let visibleWhen: (() -> Bool)?
        let enabledWhen: (() -> Bool)?
    }

    static func command(
        _ title: String, action: Selector?, target: PlayerMenuTarget = .delegate,
        key: String = "", modifiers: NSEvent.ModifierFlags = .command,
        id: PlayerMenuID? = nil, tag: Int = 0, toolTip: String? = nil,
        visibleWhen: (() -> Bool)? = nil, enabledWhen: (() -> Bool)? = nil
    ) -> PlayerMenuEntry {
        .item(
            Command(
                title: title, action: action, target: target, key: key, modifiers: modifiers,
                id: id, tag: tag, toolTip: toolTip, visibleWhen: visibleWhen, enabledWhen: enabledWhen))
    }

    static func menu(
        _ title: String, id: PlayerMenuID? = nil,
        visibleWhen: (() -> Bool)? = nil, enabledWhen: (() -> Bool)? = nil,
        _ entries: [PlayerMenuEntry]
    ) -> PlayerMenuEntry {
        .submenu(title, id: id, visibleWhen: visibleWhen, enabledWhen: enabledWhen, entries: entries)
    }
}

/// Builds AppKit menus and keeps references for dynamic sections without title-based lookups.
final class PlayerMenu: NSObject, NSMenuDelegate {
    let root = NSMenu(title: "MainMenu")
    private var visibility: [ObjectIdentifier: () -> Bool] = [:]
    private var availability: [ObjectIdentifier: () -> Bool] = [:]
    private var items: [PlayerMenuID: NSMenuItem] = [:]
    private weak var target: AnyObject?
    private weak var menuDelegate: NSMenuDelegate?

    init(entries: [PlayerMenuEntry], target: AnyObject, menuDelegate: NSMenuDelegate) {
        self.target = target
        self.menuDelegate = menuDelegate
        super.init()
        append(entries, to: root)
        refresh(root)
    }

    func item(_ id: PlayerMenuID) -> NSMenuItem? { items[id] }

    func submenu(_ id: PlayerMenuID) -> NSMenu? { items[id]?.submenu }

    /// Replaces a dynamic section in place, retaining its declared location and identity.
    func replaceContents(of id: PlayerMenuID, with entries: [PlayerMenuEntry]) {
        guard let menu = submenu(id) else { return }
        unregisterChildren(of: menu)
        menu.removeAllItems()
        append(entries, to: menu)
        refresh(menu)
    }

    private func unregisterChildren(of menu: NSMenu) {
        for item in menu.items {
            if let submenu = item.submenu { unregisterChildren(of: submenu) }
            visibility.removeValue(forKey: ObjectIdentifier(item))
            availability.removeValue(forKey: ObjectIdentifier(item))
            let ids = items.compactMap { $0.value === item ? $0.key : nil }
            for id in ids { items.removeValue(forKey: id) }
        }
    }

    private func append(_ entries: [PlayerMenuEntry], to menu: NSMenu) {
        menu.delegate = self
        // Validate native targets ourselves so enabled predicates are combined with
        // AppKit's responder validation, rather than overwritten by auto-enabling.
        menu.autoenablesItems = false
        for entry in entries {
            let item: NSMenuItem
            let id: PlayerMenuID?
            switch entry {
            case .separator:
                item = .separator()
                id = nil
            case .item(let command):
                item = NSMenuItem(title: command.title, action: command.action, keyEquivalent: command.key)
                item.keyEquivalentModifierMask = command.modifiers
                item.tag = command.tag
                item.toolTip = command.toolTip
                switch command.target {
                case .delegate: item.target = target
                case .responderChain: item.target = nil
                case .application: item.target = NSApp
                }
                visibility[ObjectIdentifier(item)] = command.visibleWhen
                availability[ObjectIdentifier(item)] = command.enabledWhen
                id = command.id
            case .submenu(let title, let menuID, let visibleWhen, let enabledWhen, let children):
                item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                let submenu = NSMenu(title: title)
                append(children, to: submenu)
                item.submenu = submenu
                visibility[ObjectIdentifier(item)] = visibleWhen
                availability[ObjectIdentifier(item)] = enabledWhen
                id = menuID
            }
            if let id = id {
                precondition(items[id] == nil, "Each player menu identity must be unique: \(id)")
                items[id] = item
            }
            menu.addItem(item)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuDelegate?.menuWillOpen?(menu)
        refresh(menu)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menuDelegate?.menuNeedsUpdate?(menu)
        refresh(menu)
    }

    /// Rechecks predicates and native validation without invoking any action.
    func refresh(_ menu: NSMenu) {
        for item in menu.items where !item.isSeparatorItem {
            if let visible = visibility[ObjectIdentifier(item)] { item.isHidden = !visible() }
            if let submenu = item.submenu { refresh(submenu) }
            let available = availability[ObjectIdentifier(item)]?() ?? true
            if item.submenu != nil {
                item.isEnabled = available
            } else {
                item.isEnabled = available && validateAction(item)
            }
        }
        // Hidden commands should not leave leading, trailing, or doubled separators.
        var previousWasSeparator = true
        for (index, item) in menu.items.enumerated() {
            if item.isSeparatorItem {
                let followedByCommand = menu.items.dropFirst(index + 1).contains {
                    !$0.isSeparatorItem && !$0.isHidden
                }
                item.isHidden = previousWasSeparator || !followedByCommand
                if !item.isHidden { previousWasSeparator = true }
            } else if !item.isHidden {
                previousWasSeparator = false
            }
        }
    }

    private func validateAction(_ item: NSMenuItem) -> Bool {
        guard let action = item.action,
            let target = item.target ?? NSApp.target(forAction: action, to: nil, from: item)
        else { return false }
        guard (target as? NSObjectProtocol)?.responds(to: action) == true else { return false }
        if let validator = target as? NSMenuItemValidation { return validator.validateMenuItem(item) }
        if let validator = target as? NSUserInterfaceValidations {
            return validator.validateUserInterfaceItem(item)
        }
        return true
    }
}
