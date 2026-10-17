import Cocoa

/// Edit titles, ordering, separators, and submenu placement here.
/// IDs bind live state to items independently of their displayed names or positions.
enum PlayerMenuLayout {
    static func main(
        appName: String, isRunning: @escaping () -> Bool, canTogglePause: @escaping () -> Bool,
        showAdvanced: @escaping () -> Bool
    ) -> [PlayerMenuEntry] {
        [
            .menu(
                appName,
                [
                    .command("About \(appName)", action: #selector(AppDelegate.showAbout(_:))),
                    .separator,
                    .command(
                        "Quit \(appName)", action: #selector(NSApplication.terminate(_:)),
                        target: .application, key: "q", modifiers: [.option, .command]),
                ]),
            .menu(
                "Edit",
                [
                    .command(
                        "Copy Text Screen", action: #selector(MainView.copyTextScreen(_:)),
                        target: .responderChain),
                    .separator,
                    .command("Paste", action: #selector(MainView.pasteText(_:)), target: .responderChain),
                ]),
            .menu(
                "Configuration", id: .configuration, enabledWhen: isRunning,
                [
                    .menu("Speed", id: .speed, []),
                    .menu("Controls", id: .controls, []),
                    .separator,
                    .command("Change ROM…", action: #selector(AppDelegate.changeROM(_:))),
                    .separator,
                    .command(
                        "Configuration  F4", action: #selector(MainView.showEmulatorConfiguration(_:)),
                        target: .responderChain, visibleWhen: showAdvanced),
                    .command(
                        "Show Debugger", action: #selector(AppDelegate.showDebugger(_:)),
                        visibleWhen: showAdvanced),
                ]),
            .menu(
                "View",
                [
                    .command(
                        "Toggle Full Screen", action: #selector(AppDelegate.toggleFullscreen(_:)),
                        key: "f", modifiers: [.control, .command]),
                    .command(
                        "Resize in Integer Multiples", action: #selector(AppDelegate.toggleIntegerResize(_:)),
                        id: .integerResize),
                    .separator,
                    .command(
                        "Save Screenshot", action: #selector(AppDelegate.takeScreenshot(_:)),
                        key: String(UnicodeScalar(NSF3FunctionKey)!), modifiers: []),
                ]),
            .menu(
                "Emulation", id: .emulation, enabledWhen: isRunning,
                [
                    .command(
                        "Pause", action: #selector(AppDelegate.togglePause(_:)), key: "p", id: .pause,
                        enabledWhen: canTogglePause),
                    .command(
                        "Reset", action: #selector(AppDelegate.resetGame(_:)),
                        toolTip: "Restart from disk with cleared RAM; keep disk data and the selected speed."),
                    .separator,
                    .command(
                        "Snapshots…", action: #selector(AppDelegate.showSnapshots(_:)),
                        key: String(UnicodeScalar(NSF2FunctionKey)!), modifiers: [], id: .snapshots),
                ]),
            .menu("Disks", id: .disks, enabledWhen: isRunning, savedDisks),
        ]
    }

    static var savedDisks: [PlayerMenuEntry] {
        [.command("Show Saved Disk", action: #selector(AppDelegate.showSavedDisk(_:)))]
    }

    static var speeds: [PlayerMenuEntry] {
        EmulationSpeed.allCases.map { speed in
            .command(speed.label, action: #selector(AppDelegate.changeSpeed(_:)), tag: speed.rawValue)
        }
    }

    static func controls(controllerName: String) -> [PlayerMenuEntry] {
        let modes: [(String, Int)] = [
            ("Automatic (Controller or Keyboard)", 4), ("Keyboard Joystick (Numeric Keypad)", 0),
            ("Mouse Joystick", 1), ("Game Controller", 2),
        ]
        return modes.map { title, type in
            .command(title, action: #selector(AppDelegate.changeControls(_:)), tag: type)
        } + [
            .separator,
            .command(controllerName, action: nil, id: .controllerStatus),
            .command("Configure Controls…", action: #selector(AppDelegate.configureControls(_:))),
        ]
    }

    static func disks(for machine: PlayerManifest) -> (
        entries: [PlayerMenuEntry], choices: [(DriveAddress, Int?)]
    ) {
        var entries: [PlayerMenuEntry] = []
        var choices: [(DriveAddress, Int?)] = []
        for address in machine.drives {
            let eject = choices.count
            choices.append((address, nil))
            var drive: [PlayerMenuEntry] = [
                .command(
                    "Eject", action: #selector(AppDelegate.swapDisk(_:)), id: .diskChoice(eject), tag: eject),
                .separator,
            ]
            for index in machine.diskFiles.indices {
                let choice = choices.count
                choices.append((address, index))
                drive.append(
                    .command(
                        machine.diskName(at: index), action: #selector(AppDelegate.swapDisk(_:)),
                        id: .diskChoice(choice), tag: choice))
            }
            entries.append(.menu(address.label, drive))
        }
        return (entries + [.separator] + savedDisks, choices)
    }
}
