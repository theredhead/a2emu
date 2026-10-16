# Apple IIGS Player Builder and Apple II Player

Swift/AppKit macOS builder and generic standalone player, using the GSplus/KEGS engine.

Builder bundle identifier: nl.theredhead.a2emu-wrapper-builder.
Exported players: nl.theredhead.a2emu-player.<normalized-disk-name>.

Choose any number of disk images, a display name, initial drive assignments and a startup slot (5, 6, or 7). The builder exports a locally signed player containing a machine profile and the selected media. A first-run ROM picker downloads ROM 03/01 or imports user firmware. No ROM or example disk is included in this source archive or the template.

The player seeds config.kegs on first launch and preserves later edits. The ROM boots from the configured slot; no startup commands are injected. Per-drive swapping/eject menus, windowed/fullscreen support and project credits with a GitHub link are included. DuckDuckGo image search in a thumbnail grid, local images and movable square crops are supported for player icons. Native GameController input, with a joystick/gamepad-only HID fallback, maps Xbox-compatible controllers to the classic Apple II analog joystick. Emulation > Controls selects Automatic, numeric keypad, mouse joystick or game controller. Configure Controls assigns left/right stick or D-pad, both joystick buttons, axis inversion and dead zone; settings are saved per player. The Numeric Keypad / Apple Keys profile maps controller directions and buttons to configurable emulated keys, including a Super Mario GS-compatible default; no physical keypad is required.

Sources adapted from GSplus revision 41e71031debbde98e66ea5c5c67498e9b4726a6d. Modifications by theredhead, 2026-10-14. GPL-3.0; see LICENSE and preserved notices. New players use the plain Apple IIgs computer artwork as their default icon; the builder adds a physical claw hammer. Custom player icons remain supported.

Build with CMake/Ninja, Xcode tools, SDL3 for upstream configuration. See the build instructions below and scripts/package-builder.sh.

The builder selects the initial CPU speed (1.0 MHz, 2.8 MHz, 8 MHz, or Unlimited). Until a speed is explicitly chosen, booting from a 3.5-inch disk or SmartPort defaults to 2.8 MHz; a 5.25-inch boot defaults to 1.0 MHz. Existing players retain their saved speed. Players can change and save speed from Emulation > Speed.

Players can be exported to start in full screen. View > Resize in Integer Multiples snaps window content dimensions to whole-number display sizes. A single configured drive automatically selects its startup slot.

## Build a universal release

Requires Xcode command line tools, CMake, Ninja and SDL3. The native player does not link SDL; upstream configuration requires it.

```sh
git clone https://github.com/digarok/gsplus.git Vendor/gsplus
git -C Vendor/gsplus checkout 41e71031debbde98e66ea5c5c67498e9b4726a6d
scripts/build-release.sh
```

The resulting builder contains a universal player template. About → More links to https://github.com/theredhead/a2emu. The website also links to GitHub for source; release packaging does not embed or generate a source archive. Releases are ad hoc signed, not notarized. Firmware, game images, test assets and generated releases remain outside Git.

Set `SDL3_PREFIX` for a different SDL3 installation. To package existing builds in another directory, run `scripts/package-builder.sh --output-dir /path/to/output`.

Existing players can be reopened by dropping their app onto the builder or using File → Open Player. Save updates the existing app, preserves its bundle identifier and saved disks, and applies revised startup defaults on the next launch. Quit the player before saving. File → New Player returns to creating a new app.

Firmware lives in `~/Library/Application Support/nl.theredhead.a2emu.player/ROMs`. Players reuse a compatible installed ROM by default while keeping independent selections through Emulation → Change ROM. Existing per-player ROMs are adopted into the shared library. No firmware is bundled.

## Swift formatting and quality checks

Use Xcode's `xcrun swift-format` and SwiftLint (`brew install swiftlint`), plus
Python 3 for the check fixtures. This pass was verified with Xcode's Swift 6.4
formatter and SwiftLint 0.65.1; formatter output can vary between toolchain versions.

```sh
scripts/swift-style.sh format  # Apply layout to Sources/**/*.swift
scripts/swift-style.sh check   # Check formatting, quality, and documentation placement
scripts/swift-style.sh test    # Prove representative mistakes fail the checks
```

The formatter uses four spaces and a 110-column target. Long string literals,
URLs, and embedded scripts may exceed that target to preserve their contents.
Only first-party `Sources` are checked; vendor code and generated bundles are excluded.
The source archive includes both tool configurations and these scripts.

Keep blank lines between methods and logical sections. Use `///` for a declaration's
purpose, contract, ownership, or failure behavior, immediately above its attributes
and declaration. Put separating blank lines before the documentation. Keep `//`
notes beside the implementation they explain; avoid comments that repeat names.

Swift-format owns layout. Explicit returns, straightforward loops, existing initializers,
and C-facing names are retained: return omission, early-exit/loop rewrites, synthesized
initializers, and naming normalization are disabled. SwiftLint uses an allowlist for
likely mistakes rather than competing layout rules, size limits, force-unwrap bans,
or shorthand preferences that would require unrelated changes to this AppKit/C bridge.

The documentation checks combine SwiftLint's orphaned-comment rule with focused regexes
for blank lines before declarations/attributes and documentation below an attribute.
The fixtures cover attached multiline documentation, correct attribute placement, and
representative failures. These are practical guards, not a full Swift documentation
parser: complex multiline attributes and unusual comment layouts still need manual
review, as do comment accuracy and meaningful method/section spacing.

## Visual controller configuration

Open **Emulation → Controls → Configure Controls** in a player. The analog profile
shows a cream, two-button joystick: click a direction to select movement settings,
or an orange button to choose its controller input. Stick and button feedback is live.

The keypad profile shows an Apple IIgs-style keypad. Click any key, then tick the
controller directions or buttons that should press it. **Keypad Defaults** assigns
4/6/8/2 and diagonal 7/9/1/3 movement. Center releases movement keys; **5 remains
assignable to a controller button**, as do 0, decimal, Enter, and the other keys.
The key menu also retains Space, Return, arrows, and the existing letter-key choices.
Save applies the working copy; Cancel leaves saved settings unchanged. Existing
players retain their older mappings until edited or reset.

Run `scripts/test-controller-mapping.sh` for eight-direction output, center/button
behavior, settings compatibility, and invalid-settings checks without hardware.

The settings heading follows the active profile. The **Controller** dropdown offers
Automatic or a specific connected controller, including direct HID connections.
Identical models have separate entries. Selection is applied on Save and lasts for
the running player; the next launch starts with Automatic. Cancel preserves the
active selection. A disconnected explicit selection remains visible until another
connection is selected.

**Emulation → Pause / Resume** (Command-P) freezes and resumes the machine. Losing
the active controller also pauses it, including when Automatic finds a replacement;
resume explicitly when ready. The paused window title identifies the interruption.

Each new export now applies its startup defaults once even when a saved-data directory
already exists for the same game. Later speed changes inside the player are preserved.
The Speed menu shows custom saved Zip speeds accurately instead of checking 8 MHz
for every Zip setting.

Additional checks: `scripts/test-controller-selection.sh` tests selection and the HID
inventory without hardware. `scripts/test-player-state.sh` uses a configured native
`build` directory and CMake to test the real configuration parser, speed menus, fresh
exports, and paused frame/timing behavior. Physical multi-controller play-testing is
still useful after these synthetic checks.

**View → Save Screenshot** uses **F3**, without Command or Option. It writes a
native-resolution PNG of the game frame to `~/Pictures/Apple II Player/<game-name>/`
with a unique timestamped filename, including while paused. A successful save plays
the macOS screenshot shutter sound. If macOS reserves F3
for Mission Control, use Fn-F3 or enable standard function keys in System Settings.
Custom Zip speeds encountered at runtime become normal, selectable Speed menu
entries for the rest of the session; the checkmark always follows the live limit.

### Machine snapshots

Open **Emulation → Snapshots…** for a thumbnail grid, with names and local date/time
for each saved moment. Save a snapshot there, select one and restore it, or import
a snapshot package from Finder. Delete moves a selected saved snapshot to the Trash.
The player's snapshots are stored in
`~/Library/Application Support/<player bundle identifier>/Snapshots/`.

Each `.a2snapshot` is a self-contained Finder package containing the machine state,
a PNG preview, metadata, and copies of every game disk, with SHA-256 integrity
checks. Restore makes fresh working disks under the player's `Snapshot Disks`
directory; it never runs from or writes into the saved package. Previous working
copies are retained, so large hard-disk snapshots and repeated restores consume
additional disk space. **Show Saved Disk** opens the player's support directory.

In the builder, choose the same disk images in the same order, then select
**Startup Snapshot…**. That snapshot is copied inside the exported app and restored
on every launch, using its captured speed and disk state. Clear the selection for
normal startup. The CLI also accepts `--snapshot /path/to/Moment.a2snapshot`.
The bundled startup snapshot also appears in the player's snapshot browser.

Machine snapshots require the exact core build, ROM contents, RAM size, and audio
sample rate used when captured. A core-source fingerprint rejects incompatible
states before restoring; updating the emulator may require new snapshots. ROMs
remain supplied through the existing ROM setup. Host-folder disks, compressed disk
mounts, partition mounts, and active serial/network connections are not captured;
the player reports those unsupported cases. Ordinary floppy/WOZ and SmartPort disk
images are supported. Save/restore runs between core ticks on the main thread;
copying large disks may briefly block the UI. Restore validates first and attempts
to recover the prior machine if mounting or disk-layout checks fail.

The adapters in `Sources/SnapshotCore` compile the upstream C units unchanged and
explicitly enumerate emulated state. They store event links as indices and rebuild
memory mappings and timing, rather than storing process addresses or host handles.
Audio output queued by the previous timeline is discarded on restore. When changing
the core, review these state lists as well as the compatibility fingerprint.

Run `scripts/test-snapshots.sh` after configuring the native build. It uses locally
supplied ROM03 and GS/OS media under `TestAssets` (not distributed), verifies a
machine round trip, continued execution, fresh-process restore, disk isolation,
corruption rejection, and a self-contained exported startup snapshot. Set
`A2_SNAPSHOT_FLOPPY=1` to exercise the local Columns WOZ fixture instead.

The native **Emulation → Reset** command performs a fresh boot: it clears volatile
RAM and sound state, while retaining mounted disks, BRAM, and the selected speed.
A warm CPU reset can return some games (including Death Sword) to their title
screen with stale music-driver initialization flags and no background music.
The emulated keyboard reset retains the core's normal warm-reset behavior.

`scripts/test-reset-audio.sh` exercises the actual macOS audio ring buffer and
render callback without opening an audio device. It needs ROM03 and a local
`TestAssets/DeathSword/Death Sword.2mg` fixture (or `A2_RESET_TEST_DISK`). It reproduces
the warm-reset music loss, then checks audio output after repeated menu resets.

### Editing player menus

`Sources/Player/PlayerMenuLayout.swift` is the menu tree: edit its `.command(...)`,
`.menu(...)`, and `.separator` entries to change labels, ordering, shortcuts,
sections, and nested menus. Commands accept `action`, `key`, `modifiers`, `target`,
`toolTip`, and optional `visibleWhen`/`enabledWhen` closures. Submenus accept child
entries and the same visibility/availability predicates. Predicates are rechecked
when menus open; enabled conditions are combined with native target/responder
validation. Hidden items do not leave leading, trailing, or doubled separators.

Keep IDs such as `.pause`, `.speed`, `.controls`, and `.disks` when renaming or
moving those items. They connect live state and dynamic contents to the declared
location. Speed options, control modes, and drive choices are also described in
this layout file; AppDelegate handles their runtime state and actions. Commands
handled by the focused emulator view use `target: .responderChain`; application
commands such as Quit use `target: .application`. F3 explicitly uses `modifiers: []`.
`PlayerMenu.swift` renders the tree into AppKit menus. No menu framework dependency
or configuration interpreter is required.

`scripts/test-player-state.sh` also checks menu grouping, shortcuts, action routing,
live predicates, separator cleanup, optional drive menus, and dynamic population
after renaming the parent menu.

When choosing new disks, the builder detects the first image’s boot device and mounts it in drive 1.
HDV selects SmartPort; 2MG payload size and WOZ media headers distinguish floppy types.
Raw 140/160 KB images select 5.25-inch, 400/800 KB images select 3.5-inch, and larger images select SmartPort.
Unknown 2MG images default to 3.5-inch. Drive and startup selections remain editable; opening an existing player preserves its configuration.
CLI exports also detect the device when `--boot-slot` is omitted.
Run `scripts/test-disk-image-device.sh` to check detection, initial mounting, and manual overrides.
