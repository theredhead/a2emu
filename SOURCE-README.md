# Apple II Player and Wrapper Builder

Swift/AppKit macOS builder and generic standalone player, using the GSplus/KEGS engine.

Builder bundle identifier: nl.theredhead.a2emu-wrapper-builder.
Exported players: nl.theredhead.a2emu-player.<normalized-disk-name>.

Choose any number of disk images, a display name, initial drive assignments and a startup slot (5, 6, or 7). The builder exports a locally signed player containing a machine profile and the selected media. A first-run ROM picker downloads ROM 03/01 or imports user firmware. No ROM or example disk is included in this source archive or the template.

The player seeds config.kegs on first launch and preserves later edits. The ROM boots from the configured slot; no startup commands are injected. Per-drive swapping/eject menus, windowed/fullscreen support and project credits with embedded source are included. DuckDuckGo image search, local images and movable square crops are supported for player icons. Gamepad mapping and the wider exporter interface are still in development.

Sources adapted from GSplus revision 41e71031debbde98e66ea5c5c67498e9b4726a6d. Modifications by theredhead, 2026-10-14. GPL-3.0; see LICENSE and preserved notices. Generic fallback artwork comes from KEGS/GSplus.

Build with CMake/Ninja, Xcode tools, Python 3 and SDL3 for upstream configuration. See BUILDING.txt and scripts/package-builder.py.

The builder selects the initial CPU speed (1.0 MHz, 2.8 MHz, 8 MHz, or Unlimited). Players can change and save speed from Emulation > Speed.

Players can be exported to start in full screen. View > Resize in Integer Multiples snaps window content dimensions to whole-number display sizes. A single configured drive automatically selects its startup slot.
