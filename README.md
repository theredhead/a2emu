# Apple II Player and Wrapper Builder

Swift/AppKit macOS builder and generic standalone player, using the GSplus/KEGS engine.

Builder bundle identifier: nl.theredhead.a2emu-wrapper-builder.
Exported players: nl.theredhead.a2emu-player.<normalized-disk-name>.

Choose any number of disk images, a display name, initial drive assignments and a startup slot (5, 6, or 7). The builder exports a locally signed player containing a machine profile and the selected media. A first-run ROM picker downloads ROM 03/01 or imports user firmware. No ROM or example disk is included in this source archive or the template.

The player seeds config.kegs on first launch and preserves later edits. The ROM boots from the configured slot; no startup commands are injected. Per-drive swapping/eject menus, windowed/fullscreen support and project credits with embedded source are included. DuckDuckGo image search, local images and movable square crops are supported for player icons. Native GameController input, with a joystick/gamepad-only HID fallback, maps Xbox-compatible controllers to the classic Apple II analog joystick. Emulation > Controls selects Automatic, numeric keypad, mouse joystick or game controller. Configure Controls assigns left/right stick or D-pad, both joystick buttons, axis inversion and dead zone; settings are saved per player. The Numeric Keypad / Apple Keys profile maps controller directions and buttons to configurable emulated keys, including a Super Mario GS-compatible default; no physical keypad is required.

Sources adapted from GSplus revision 41e71031debbde98e66ea5c5c67498e9b4726a6d. Modifications by theredhead, 2026-10-14. GPL-3.0; see LICENSE and preserved notices. Generic fallback artwork comes from KEGS/GSplus.

Build with CMake/Ninja, Xcode tools, SDL3 for upstream configuration. See the build instructions below and scripts/package-builder.sh.

The builder selects the initial CPU speed (1.0 MHz, 2.8 MHz, 8 MHz, or Unlimited). Players can change and save speed from Emulation > Speed.

Players can be exported to start in full screen. View > Resize in Integer Multiples snaps window content dimensions to whole-number display sizes. A single configured drive automatically selects its startup slot.

## Build a universal release

Requires Xcode command line tools, CMake, Ninja and SDL3. The native player does not link SDL; upstream configuration requires it.

```sh
git clone https://github.com/digarok/gsplus.git Vendor/gsplus
git -C Vendor/gsplus checkout 41e71031debbde98e66ea5c5c67498e9b4726a6d
scripts/build-release.sh
```

The resulting builder contains a universal player template and embedded corresponding source. Releases are ad hoc signed, not notarized. Firmware, game images, test assets and generated releases remain outside Git.

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
