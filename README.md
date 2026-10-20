# Apple IIGS Player Builder

Turn Apple II and IIGS disk images into standalone Mac apps, powered by GSplus/KEGS.
Runs on macOS 13 or later, on Intel and Apple Silicon.

## Create a player

1. Choose or drop your disk images and enter an app name.
2. Review the detected boot device and initial disk assignments. Leave extra disks
   unmounted to swap them in while playing.
3. Choose the initial speed, expansion RAM, fullscreen preference and optional icon.
4. Click **Create Player…** and choose where to save the app.

Hold **Option** to change **Create Player…** (or **Save** while editing) to **Run Now**.
This launches a temporary player with the current settings without asking for a save location.
Its app and test saved data are removed when the player quits; your source disks and existing player are preserved.


You can also choose or drop a startup snapshot. Its bundled disks, game name, RAM
and disk mounts fill in the setup automatically; the saved state restores the speed.

The builder starts at 2.8 MHz and detects the first disk’s likely drive type. Until you choose a speed,
5.25-inch boots default to 1.0 MHz; 3.5-inch and SmartPort boots default to 2.8 MHz.
Expansion RAM is additional to the ROM model’s built-in memory and defaults to 8 MB.

On first launch, the player offers ROM setup. No firmware or game disks are bundled
with the builder. Compatible installed ROMs are shared between players; use
**Configuration → Change ROM…** to choose another.

To edit a player, quit it, then drop its app onto the builder or choose
**File → Open Player…**. Save updates the app while preserving its saved disks.

Use **File → New Blank Disk Image…** to create a ProDOS-formatted floppy or SmartPort
disk, a DOS 3.3 data disk (140 KB), or an unformatted image. No operating system is included.

## First launch

The apps are locally signed and are not notarized by Apple. If macOS blocks the
builder, use **System Settings → Privacy & Security → Open Anyway**. Alternatively,
after moving it to Applications, run:

```sh
xattr -dr com.apple.quarantine "/Applications/Apple IIGS Player Builder.app"
```

Use the app’s actual path if it is somewhere else. Exported players transferred to
another Mac may need the same first-launch approval.

## Playing

- **Disks:** each drive lists compatible images that are not mounted elsewhere.
  Drop an image onto the player to use a disposable copy in the first free compatible
  drive, or choose which disk to eject if those drives are occupied. Hold Option while
  dropping to add the image and its drive assignment permanently to the portable app.
  Changed disposable disks can be saved back to their original files using
  **Save Changes to Temporary Media…**; another location is offered if that fails.
  Quitting prompts only when disposable disks still have unsaved changes.
  Filename collisions ask for a new name.
- **Configuration → Controls → Configure Controls:** assign controller directions and
  buttons using the joystick or keyboard/keypad layout. For keyboard-only games,
  choose **Keyboard & Mouse**, click a key on the IIGS keyboard, then activate the
  controller direction or button that should press it. Both sticks can have separate
  bindings. The same view includes the numpad. Letters, numbers, arrows, and keypad keys (including diagonals
  and keypad 5) are supported. Menu / Start and Options / Select can also be assigned
  when the selected controller exposes them through macOS. The single-button ADB mouse
  supports controller-button clicks. Select its body to bind all four directions to a stick
  or D-pad, or select an arrow to bind a mouse direction individually.
- **Configuration → Speed:** change the running speed; the checkmark follows the emulator.
- **Emulation → Pause / Resume** (**Command-P**): pause or continue. Losing the active
  controller also pauses the game. Player dialogs pause while open; closing them
  preserves any manual or controller-disconnect pause.
- **Emulation → Reset:** restart the machine with the current disks and speed.
- **View → Save Screenshot** (**F3**): save a PNG to
  `~/Pictures/Apple II Player/<game-name>/`. Use Fn-F3 if macOS reserves F3.

Hold **Option** while opening **Configuration** to reveal the advanced configuration
and **Show Debugger** commands.

Player disk changes and snapshots are kept in Application Support, separately from
its bundled originals. **Disks → Show Saved Disk** opens that player’s folder.

## Snapshots

Open **Emulation → Snapshots…** (**F2**) to save, browse, restore, import or delete snapshots.
Emulation pauses while this window is open. Closing it resumes play unless the
player was already paused or another pause occurred while browsing.
Each snapshot includes its machine state, preview and game disks. New saves use
compression and have descriptive filenames and Finder preview icons.

To start a player from a snapshot, choose the matching disks in the same order in
the builder, then choose **Startup Snapshot…**. The exported app restores it on every
launch. Its captured RAM size and speed take precedence over normal startup settings.
Clear the snapshot selection to boot normally.

Snapshots require a compatible emulator build and the same ROM. Keep ordinary disk
saves too: an emulator update may require a new snapshot. Large disk images and
repeated restores can use considerable disk space.

## Source and credits

Created by theredhead, using Kent Dickey’s KEGS and Dagen Brock’s GSplus.
Distributed under [GPL-3.0](LICENSE); firmware and games are separate.

[Source on GitHub](https://github.com/theredhead/a2emu) ·
[Build, test and contributor guide](DEVELOPMENT.md)
