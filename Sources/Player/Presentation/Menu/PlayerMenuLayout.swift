import Cocoa

private let commonIntl = CommonIntl()
private let playerMenuIntl = PlayerMenuIntl()

/// Edit titles, ordering, separators, and submenu placement here.
/// IDs bind live state to items independently of their displayed names or positions.
enum PlayerMenuLayout {
    static func main(
        appName: String, isRunning: @escaping () -> Bool, canTogglePause: @escaping () -> Bool,
        showAdvanced: @escaping () -> Bool, canSaveTemporaryMedia: @escaping () -> Bool = { false }
    ) -> [PlayerMenuEntry] {
        [
            .menu(
                appName,
                [
                    .command(
                        playerMenuIntl.about(appName: appName),
                        action: #selector(PlayerMenuActions.showAbout(_:))),
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
                    .command(playerMenuIntl.changeRom, action: #selector(PlayerMenuActions.changeROM(_:))),
                    .separator,
                    .command(
                        playerMenuIntl.configurationF4,
                        action: #selector(MainView.showEmulatorConfiguration(_:)),
                        target: .responderChain, visibleWhen: showAdvanced),
                    .command(
                        playerMenuIntl.showDebugger, action: #selector(PlayerMenuActions.showDebugger(_:)),
                        visibleWhen: showAdvanced),
                ]),
            .menu(
                playerMenuIntl.view,
                [
                    .command(
                        playerMenuIntl.toggleFullScreen,
                        action: #selector(PlayerMenuActions.toggleFullscreen(_:)),
                        key: "f", modifiers: [.control, .command]),
                    .command(
                        playerMenuIntl.resizeInIntegerMultiples,
                        action: #selector(PlayerMenuActions.toggleIntegerResize(_:)),
                        id: .integerResize),
                    .separator,
                    .command(
                        playerMenuIntl.saveScreenshot,
                        action: #selector(PlayerMenuActions.takeScreenshot(_:)),
                        key: String(UnicodeScalar(NSF3FunctionKey)!), modifiers: []),
                ]),
            .menu(
                playerMenuIntl.emulation, id: .emulation, enabledWhen: isRunning,
                [
                    .command(
                        commonIntl.pause, action: #selector(PlayerMenuActions.togglePause(_:)), key: "p",
                        id: .pause,
                        enabledWhen: canTogglePause),
                    .command(
                        commonIntl.reset, action: #selector(PlayerMenuActions.resetGame(_:)),
                        toolTip: playerMenuIntl.restartFromDiskWithClearedRam),
                    .separator,
                    .command(
                        commonIntl.snapshots, action: #selector(PlayerMenuActions.showSnapshots(_:)),
                        key: String(UnicodeScalar(NSF2FunctionKey)!), modifiers: [], id: .snapshots),
                ]),
            .menu(
                playerMenuIntl.disks, id: .disks, enabledWhen: isRunning,
                savedDisks(canSaveTemporaryMedia: canSaveTemporaryMedia)),
        ]
    }

    static func savedDisks(canSaveTemporaryMedia: @escaping () -> Bool = { false }) -> [PlayerMenuEntry] {
        [
            .command(
                playerMenuIntl.saveTemporaryMedia,
                action: #selector(PlayerMenuActions.saveTemporaryMedia(_:)),
                id: .saveTemporaryMedia, visibleWhen: canSaveTemporaryMedia),
            .separator,
            .command(playerMenuIntl.showSavedDisk, action: #selector(PlayerMenuActions.showSavedDisk(_:))),
        ]
    }

    static var speeds: [PlayerMenuEntry] {
        EmulationSpeed.allCases.map { speed in
            .command(speed.label, action: #selector(PlayerMenuActions.changeSpeed(_:)), tag: speed.rawValue)
        }
    }

    static func controls(controllerName: String) -> [PlayerMenuEntry] {
        let modes: [(String, Int)] = [
            (playerMenuIntl.automaticControllerOrKeyboard, 4),
            (playerMenuIntl.keyboardJoystickNumericKeypad, 0),
            (playerMenuIntl.mouseJoystick, 1), (playerMenuIntl.gameController, 2),
        ]
        return modes.map { title, type in
            .command(title, action: #selector(PlayerMenuActions.changeControls(_:)), tag: type)
        } + [
            .separator,
            .command(controllerName, action: nil, id: .controllerStatus),
            .command(
                playerMenuIntl.configureControls, action: #selector(PlayerMenuActions.configureControls(_:))),
        ]
    }

    static func disks(
        for machine: PlayerManifest, canSaveTemporaryMedia: @escaping () -> Bool = { false }
    ) -> (
        entries: [PlayerMenuEntry], choices: [(DriveAddress, Int?)]
    ) {
        var entries: [PlayerMenuEntry] = []
        var choices: [(DriveAddress, Int?)] = []
        for address in machine.drives {
            let eject = choices.count
            choices.append((address, nil))
            var drive: [PlayerMenuEntry] = [
                .command(
                    playerMenuIntl.eject, action: #selector(PlayerMenuActions.swapDisk(_:)),
                    id: .diskChoice(eject),
                    tag: eject),
                .separator,
            ]
            for index in machine.diskFiles.indices {
                let choice = choices.count
                choices.append((address, index))
                drive.append(
                    .command(
                        machine.diskName(at: index), action: #selector(PlayerMenuActions.swapDisk(_:)),
                        id: .diskChoice(choice), tag: choice))
            }
            entries.append(.menu(address.label, drive))
        }
        return (entries + [.separator] + savedDisks(canSaveTemporaryMedia: canSaveTemporaryMedia), choices)
    }
}
