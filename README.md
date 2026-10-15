# Apple II Player and Wrapper Builder

Swift/AppKit macOS builder and generic standalone player, using the GSplus/KEGS engine.

Builder bundle identifier: nl.theredhead.a2emu-wrapper-builder.
Exported players: nl.theredhead.a2emu-player.<normalized-disk-name>.

Choose any number of disk images, a display name, initial drive assignments and a startup slot (5, 6, or 7). The builder exports a locally signed player containing a machine profile and the selected media. A first-run ROM picker downloads ROM 03/01 or imports user firmware. No ROM or example disk is included in this source archive or the template.

The player seeds config.kegs on first launch and preserves later edits. The ROM boots from the configured slot; no startup commands are injected. Per-drive swapping/eject menus, windowed/fullscreen support and project credits with embedded source are included. DuckDuckGo image search, local images and movable square crops are supported for player icons. Gamepad mapping and the wider exporter interface are still in development.

Sources adapted from GSplus revision 41e71031debbde98e66ea5c5c67498e9b4726a6d. Modifications by theredhead, 2026-10-14. GPL-3.0; see LICENSE and preserved notices. Generic fallback artwork comes from KEGS/GSplus.

Build with CMake/Ninja, Xcode tools, Python 3 and SDL3 for upstream configuration. See the build instructions below and scripts/package-builder.py.

The builder selects the initial CPU speed (1.0 MHz, 2.8 MHz, 8 MHz, or Unlimited). Players can change and save speed from Emulation > Speed.

Players can be exported to start in full screen. View > Resize in Integer Multiples snaps window content dimensions to whole-number display sizes. A single configured drive automatically selects its startup slot.

## Build a universal release

Requires Xcode command line tools, CMake, Ninja, Python 3 and SDL3. The native player does not link SDL; upstream configuration requires it.

```sh
git clone https://github.com/digarok/gsplus.git Vendor/gsplus
git -C Vendor/gsplus checkout 41e71031debbde98e66ea5c5c67498e9b4726a6d
for arch in arm64 x86_64; do
  cmake -G Ninja -B "build/release-$arch" -S . -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="$arch" -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/sdl3 "-DCMAKE_Swift_FLAGS=-module-cache-path /tmp/a2-swift-module-cache-$arch"
  cmake --build "build/release-$arch" --target a2emu-player a2emu-builder
done
python3 scripts/package-builder.py
```

The resulting builder contains a universal player template and embedded corresponding source. Releases are ad hoc signed, not notarized. Firmware, game images, test assets and generated releases remain outside Git.
