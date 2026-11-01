# AppleJuicer and JuiceBox architecture

First-party Swift is grouped by product (`Builder`, `Player`, `Shared`) and responsibility:

| Folder | Responsibility | Dependencies |
| --- | --- | --- |
| `Application` | AppKit lifecycle, commands and workflow orchestration | Domain values, infrastructure services, presentation components |
| `Domain` | Configuration, binding validation, boot/pause policy and capture state | Foundation and shared typed message resources; no filesystem, preferences, network or UI frameworks |
| `Infrastructure` | Files, bundles, signing, process launch, firmware transfer, controller APIs and emulator memory | Domain values and the platform APIs each adapter owns |
| `Presentation` | Windows, controls, dialogs, menu items, image cropping and display | Domain/read-model values and explicit actions/callbacks |
| `Shared/Intl` | Typed localization lookup and formatting | Foundation and localization resources |

These folders reflect ownership boundaries in the implementation. Moving a file does not establish
separation on its own. Domain policy never reaches through a view or a global application singleton.
Application coordinators decide when services run and translate outcomes into presentation updates.
Infrastructure adapters do not open alerts or reach back into application delegates.

## Builder ownership

- `Builder` is the application coordinator and action target. It manages the selected document and
  sequences user workflows; it no longer owns the form's controls, export process, preview process,
  extracted-snapshot directory, or filesystem transactions.
- `BuilderForm` owns controls, layout and editable disk rows. `BuilderFormActions` is its action surface.
  It captures an immutable `PlayerBuildConfiguration` instead of handing controls to export code.
- `PlayerBuildConfiguration` validates build intent; `BootReadiness` decides which selected mount matters.
  Disk parsing is an infrastructure extension of the `DiskBootability` evidence value.
- `PlayerBuildService` creates, updates or prepares disposable previews from one captured configuration.
  Its template, file manager and launch closure are explicit dependencies. `TemporaryPlayerLauncher`
  owns subprocess launch and exit cleanup. Failed preparation removes its workspace.
- `BuilderPlayerDocument` reads validated bundle metadata. `BuilderSnapshotWorkspace` owns extracted
  snapshot media and removes it on release, including failed imports.
- `BlankDiskCreationPanel` owns its dialog and callback lifetimes; the application asks the formatter
  to write only after selection and overwrite checks. `IconPicker` owns its search/crop UI, while
  `SquareCropView` owns crop rendering and `ArtworkLoader` owns asynchronous byte loading.

## Player ownership

- `AppDelegate` sequences startup, commands and session transitions. Its AppKit callbacks invoke
  narrower owners instead of implementing persistence transactions or retaining native pixel pointers.
- `PlayerStorage` resolves bundle identity and seeds missing originals. A support root can be injected
  for isolated tests. Legacy paths remain usable without rewriting saved absolute disk paths.
- `PlayerConfigurationStore` owns `config.kegs` default revisions and mount decoding.
  `ImportedDiskLibrary` owns the imported-media index and copy/rollback transaction.
  `PortableDiskWriter` stages, signs and replaces portable bundles atomically.
- `EmulationPause` combines independent manual/dialog ownership. `ControllerMapping` validates numeric
  binding data; `ControllerSettingsStore` owns its unchanged preferences key and JSON encoding.
  Localized binding labels belong to the editor's presentation extension. `ControllerBindingCapture`
  owns neutral gating independently of the keyboard view.
- `PlayerWindowCoordinator` owns focus, fullscreen and integer sizing. `EmulatorWindow` owns each native
  window/view pairing. `PlayerSpeedMenu` owns discovered speed items; `PlayerDiskMenu` owns disk choices
  and compatibility display. Both render supplied state and route actions rather than reading the core.
- `MainView` handles native display/input presentation through an explicit weak `PlayerViewSession`.
  `PlayerMenuActions` supplies typed selector declarations without referencing the concrete app delegate.
  `SnapshotBrowserSession` supplies browser commands; `SnapshotLibrary` owns catalogue reads, imports,
  legacy naming and trash operations. `EmulatorWindow` receives its window coordinator and session explicitly. `EmulatorFramebuffer` privately owns bitmap
  memory and renderer pointer use. `ScreenshotStore` publishes immutable frames with unique filenames.
- `ROMLibrary` owns firmware validation/storage. `ROMDownload` owns a cancellable ephemeral session and
  verified byte assembly, with main-thread completions. `ROMSetup` owns choices and modal progress.
- Application media/snapshot workflows coordinate core calls, storage adapters, prompts and menus.
  The core remains process-wide and accessed between ticks on the main thread.

## Native and persistence boundaries

`EmulatorCore.Image` is a Swift handle with private borrowed C storage. `ControllerHardware` copies
borrowed controller names before returning them. Raw pixel pointers stay inside `EmulatorFramebuffer`;
views receive immutable `CGImage` frames. C bridges and snapshot core files retain their original
locations and contents. The core compatibility fingerprint is unchanged by this Swift refactor.

Profile JSON, snapshots, preferences, bundle identifiers, configuration keys, saved-data paths, export
creation dates and portable-media behavior remain unchanged. New source groups are discovered by CMake
and the test source manifest (`scripts/swift-sources.sh`) from the same architectural roots.

## Review and verification

The 200-line guideline is a responsibility-review trigger, not a quota. The remaining larger application
coordinators implement lifecycle/action sequencing; the controller editor owns one working-copy editing
workflow and its preview controls. Their persistence, domain rules, rendering memory and platform resource
lifetimes are separate objects. Future changes should extend those owners rather than put storage or
hardware decisions back into coordinators. Do not split files into extensions to disguise size.

`python3 scripts/check-architecture.py` enforces source roles, UI-free domain imports, infrastructure-owned
raw memory, and delegated network/process ownership. It complements purpose-comment/spacing checks and
manual design review; it cannot prove SOLID design. Both checks run in `zsh swift-baseline.sh check`.

Use `scripts/test-architecture.sh` for isolated storage identity, default revisions, preview cleanup,
firmware verification/cancellation and pause ownership. The existing builder, controller, localization,
player-state, snapshot, startup and audio regressions exercise the application integrations.
