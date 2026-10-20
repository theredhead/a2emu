# Development

The native Swift/AppKit frontend uses GSplus revision
`41e71031debbde98e66ea5c5c67498e9b4726a6d`. Upstream sources remain in `Vendor/gsplus`.
See [MODIFICATIONS.txt](MODIFICATIONS.txt) for adaptation notes.

## Build and package

Requires Xcode command line tools, CMake, Ninja and SDL3. Upstream configuration
requires SDL3; the native player does not link it.

```sh
git clone https://github.com/digarok/gsplus.git Vendor/gsplus
git -C Vendor/gsplus checkout 41e71031debbde98e66ea5c5c67498e9b4726a6d
scripts/build-release.sh
```

Set `SDL3_PREFIX` for a different SDL3 installation. Package existing architecture
builds with `scripts/package-builder.sh`, optionally adding `--output-dir DIRECTORY`.
The universal builder embeds a player template. Source links point to GitHub;
source archives are not embedded. `scripts/bundle-source.sh` is available separately.
Firmware, game images, local test fixtures and generated releases are excluded from Git.

Website packaging and Docker deployment are documented in [Website/README.md](Website/README.md).

## Swift style

Use `xcrun swift-format`, SwiftLint and Python 3 for the documentation-check fixtures:

```sh
scripts/swift-style.sh format
scripts/swift-style.sh check
scripts/swift-style.sh test
```

Use four spaces, a 110-column target, and blank lines between methods and logical
sections. Use lowerCamelCase for Swift functions, properties, variables and argument
labels, and UpperCamelCase for types. Keep explicit returns and straightforward loops.
Layout and Swift naming belong to swift-format; SwiftLint checks likely mistakes
without imposing competing layout or shorthand rules. Vendor code and generated
bundles are excluded.

`EmulatorCore` and `ControllerHardware` isolate the imported emulator/HID C symbols.
Keep native names in these boundaries and Swift names at call sites. The core is
process-wide and accessed on the main thread; image pointers are borrowed, never
owned by Swift. Snapshot failures become Swift errors and C strings are copied
before returning to callers. Raw C configuration keys remain unchanged on disk.

Use `///` for purpose, contracts, ownership and failure behavior, immediately above
the declaration and its attributes. Put separating blank lines before documentation.
Keep `//` implementation notes beside the statements they explain. Automated checks
catch common detached documentation; comment accuracy still needs manual review.

## Tests

Configure a native `build` directory before running tests that link the emulator.
Local firmware and game fixtures live under ignored `TestAssets`; each integration
script describes its required fixtures or environment overrides.

| Command | Coverage |
| --- | --- |
| `scripts/test-controller-mapping.sh` | Directions, diagonals, center/button behavior, settings validation |
| `scripts/test-controller-selection.sh` | Native/HID routing, device selection and disconnects |
| `scripts/test-disk-image-device.sh` | Media detection, initial mounting, speed defaults and RAM choices |
| `scripts/test-icon-picker.sh` | Single-click selection and stable incremental search results; requires WebKit UI services |
| `scripts/test-player-state.sh` | Configuration, live speed menus, declarative menus, screenshots and pause timing |
| `scripts/test-snapshots.sh` | Compression, round trips, fresh-process restore, disk isolation, corruption, rollback and export |
| `scripts/test-snapshot-startup.sh` | Rastan cold-restore display, keyboard input, second-disk mounting, Finder presentation and low RAM |
| `scripts/test-reset-audio.sh` | Death Sword reset audio through the native render callback |

Set `A2_SNAPSHOT_FLOPPY=1` for the Columns WOZ snapshot fixture. The startup regression
uses `TestAssets/Rastan/Rastan.app`, or `A2_SNAPSHOT_TEST_PLAYER`. The reset test accepts
`A2_RESET_TEST_DISK`. Hardware controller and audio checks remain useful alongside
these device-independent tests.

## Player menus

Edit the tree in `Sources/Player/PlayerMenuLayout.swift` using `.command(...)`,
`.menu(...)` and `.separator`. Entries support native actions, shortcuts, targets,
tooltips, children, and `visibleWhen` / `enabledWhen` predicates. Predicates refresh
when menus open and combine with native action validation.

Retain stable IDs such as `.pause`, `.speed`, `.controls` and `.disks` when moving or
renaming entries. They connect runtime state and dynamic contents to the layout.
Use `.responderChain` for focused-view actions and `.application` for app actions.
F3 uses `modifiers: []`. Option at top-level menu opening enables advanced menu
items through the shared `showAdvanced` visibility predicate; submenus inherit that
mode, and the next ordinary opening hides them again. `PlayerMenu.swift` renders the tree and cleans up separators.

## Configuration and snapshots

The builder identifier is `nl.theredhead.a2emu-wrapper-builder`; exported identifiers
start with `nl.theredhead.a2emu-player`. Keep them stable across display-name changes.
The player seeds `config.kegs` and applies each exported configuration revision once,
then preserves player-side changes. ROMs are shared under
`~/Library/Application Support/nl.theredhead.a2emu.player/ROMs`.

`Sources/SnapshotCore` wraps unmodified upstream translation units and enumerates
serialized state. Event links use indices; process pointers and host handles are
rebuilt. Review state lists and the compatibility fingerprint when changing the core.
Restore discards queued host audio and invalidates derived video caches on the next
tick. The saved preview supplies an immediate frame, including while paused.

Snapshot packages contain metadata, an uncompressed PNG preview and disk/state
payloads with integrity checks. Format 2 supports LZFSE payload compression; format 1
remains readable. Payloads above 64 MB remain uncompressed to bound peak memory.
Expanded sizes and checksums are verified before applying state. Startup snapshots
select their captured expansion RAM. Finder icon metadata is stripped only from
bundled copies before signing the exported app.

Snapshots require matching core, ROM, RAM and audio rate. Host-folder, compressed
or partition disk mounts and active serial/network connections are unsupported.
Restore uses fresh writable disk copies and attempts to roll back if mounting or
layout validation fails. These working copies are retained under `Snapshot Disks`.

## Shared Swift baseline

Run `zsh swift-baseline.sh format` and `zsh swift-baseline.sh check` for the checked-in four-space, 110-column Swift style and focused SwiftLint rules. These explicit configurations supersede formatter defaults. See `AGENTS.md` for SOLID design, ownership and native Swift wrapper requirements. Vendored dependencies and generated app copies are excluded.
