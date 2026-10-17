import Cocoa

private let commonIntl = CommonIntl()
private let playerMenuIntl = PlayerMenuIntl()

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
                    .command(
                        playerMenuIntl.about(appName: appName), action: #selector(AppDelegate.showAbout(_:))),
                    .separator,
                    .command(
                        playerMenuIntl.quit(appName: appName), action: #selector(NSApplication.terminate(_:)),
                        target: .application, key: "q", modifiers: [.option, .command]),
                ]),
            .menu(
                playerMenuIntl.edit,
                [
                    .command(
                        playerMenuIntl.copyTextScreen, action: #selector(MainView.copyTextScreen(_:)),
                        target: .responderChain),
                    .separator,
                    .command(
                        playerMenuIntl.paste, action: #selector(MainView.pasteText(_:)),
                        target: .responderChain),
                ]),
            .menu(
                playerMenuIntl.configuration, id: .configuration, enabledWhen: isRunning,
                [
                    .menu(playerMenuIntl.speed, id: .speed, []),
                    .menu(playerMenuIntl.controls, id: .controls, []),
                    .separator,
                    .command(playerMenuIntl.changeRom, action: #selector(AppDelegate.changeROM(_:))),
                    .separator,
                    .command(
                        playerMenuIntl.configurationF4,
                        action: #selector(MainView.showEmulatorConfiguration(_:)),
                        target: .responderChain, visibleWhen: showAdvanced),
                    .command(
                        playerMenuIntl.showDebugger, action: #selector(AppDelegate.showDebugger(_:)),
                        visibleWhen: showAdvanced),
                ]),
            .menu(
                playerMenuIntl.view,
                [
                    .command(
                        playerMenuIntl.toggleFullScreen, action: #selector(AppDelegate.toggleFullscreen(_:)),
                        key: "f", modifiers: [.control, .command]),
                    .command(
                        playerMenuIntl.resizeInIntegerMultiples,
                        action: #selector(AppDelegate.toggleIntegerResize(_:)),
                        id: .integerResize),
                    .separator,
                    .command(
                        playerMenuIntl.saveScreenshot, action: #selector(AppDelegate.takeScreenshot(_:)),
                        key: String(UnicodeScalar(NSF3FunctionKey)!), modifiers: []),
                ]),
            .menu(
                playerMenuIntl.emulation, id: .emulation, enabledWhen: isRunning,
                [
                    .command(
                        commonIntl.pause, action: #selector(AppDelegate.togglePause(_:)), key: "p",
                        id: .pause,
                        enabledWhen: canTogglePause),
                    .command(
                        commonIntl.reset, action: #selector(AppDelegate.resetGame(_:)),
                        toolTip: playerMenuIntl.restartFromDiskWithClearedRam),
                    .separator,
                    .command(
                        commonIntl.snapshots, action: #selector(AppDelegate.showSnapshots(_:)),
                        key: String(UnicodeScalar(NSF2FunctionKey)!), modifiers: [], id: .snapshots),
                ]),
            .menu(playerMenuIntl.disks, id: .disks, enabledWhen: isRunning, savedDisks),
        ]
    }

    static var savedDisks: [PlayerMenuEntry] {
        [.command(playerMenuIntl.showSavedDisk, action: #selector(AppDelegate.showSavedDisk(_:)))]
    }

    static var speeds: [PlayerMenuEntry] {
        EmulationSpeed.allCases.map { speed in
            .command(speed.label, action: #selector(AppDelegate.changeSpeed(_:)), tag: speed.rawValue)
        }
    }

    static func controls(controllerName: String) -> [PlayerMenuEntry] {
        let modes: [(String, Int)] = [
            (playerMenuIntl.automaticControllerOrKeyboard, 4),
            (playerMenuIntl.keyboardJoystickNumericKeypad, 0),
            (playerMenuIntl.mouseJoystick, 1), (playerMenuIntl.gameController, 2),
        ]
        return modes.map { title, type in
            .command(title, action: #selector(AppDelegate.changeControls(_:)), tag: type)
        } + [
            .separator,
            .command(controllerName, action: nil, id: .controllerStatus),
            .command(playerMenuIntl.configureControls, action: #selector(AppDelegate.configureControls(_:))),
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
                    playerMenuIntl.eject, action: #selector(AppDelegate.swapDisk(_:)), id: .diskChoice(eject),
                    tag: eject),
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
