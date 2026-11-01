# Swift development baseline

The Apple IIgs Player Builder baseline applies to all first-party Swift in this project. Use the checked-in `.swift-format` and `.swiftlint.yml`. Run `zsh swift-baseline.sh format`, then `zsh swift-baseline.sh check`, relevant tests and the existing app build. Four spaces, a 110-column target, blank lines between methods/logical sections, explicit returns and correctly attached documentation are required. Exclude vendor code and generated copies.

Require readable, well architected code following SOLID design. Keep responsibilities cohesive and dependencies explicit; separate UI, domain rules, persistence and platform adapters. Use narrow interfaces where substitution or ownership needs them, not speculative layers. Focused files and extensions help navigation but do not alone establish separation of responsibilities.

Imported C APIs belong behind native Swift wrappers. Keep raw handles, pointers, callbacks, C constants and cleanup private to the owning adapter. Expose Swift names, values, errors and lifetime semantics. Copy borrowed results before returning them and document thread affinity. Preserve persisted data encodings and user-visible behavior during readability changes.

Preserve unrelated local work. The user authorizes verified readability changes to be committed as `readability refactor round` and pushed to an existing configured origin. Do not invent a remote or stage unrelated files.

## Readability additions adopted from VirtualMac (ElseBox)

Inherit the shared Swift baseline from the parent workspace. These additions supplement
all project rules above; local rules without an ElseBox counterpart remain in force.

- Every class, including private helper classes, needs a `///` purpose comment directly
  above its attributes/declaration. Explain why it exists and what it owns; do not
  merely restate its name.
- Separate methods and computed members with one blank line. Group stored properties
  and method bodies into short, coherent paragraphs.
- Prefer short, clearly named methods. A class approaching roughly 200 code lines
  deserves a responsibility review; this is guidance, not a numeric pass/fail rule.
  Do not hide size with extensions or create forwarding types solely to meet a quota.
- Extract objects that own a coherent decision, resource lifetime, UI component or
  workflow. Keep their inputs/callbacks narrow and document their ownership boundary.
- `python3 scripts/check-readability.py` checks purpose-comment presence and declaration
  whitespace. Its `--fix` mode inserts whitespace only. Prose quality and architecture
  still require human/model review. The check is included in `zsh swift-baseline.sh check`.
- After adding/removing/moving Swift sources, update `CMakeLists.txt` and any explicit
  source lists in test scripts. Keep physical folders grouped by purpose. This project
  uses CMake rather than ElseBox's Xcode source-sync script.
- After changes, run `zsh swift-baseline.sh format`, `zsh swift-baseline.sh check`, relevant
  tests, and `cmake --build build --target a2emu-builder a2emu-player`.
- All first-party app, helper, and test bundle identifiers use the `nl.theredhead` base.

## Architecture enforcement

Follow the responsibility and ownership map in `ARCHITECTURE.md`. First-party Swift
belongs in the product's `Application`, `Domain`, `Infrastructure`, or `Presentation`
folders; typed shared localization remains in `Shared/Intl`. Run
`python3 scripts/check-architecture.py` (included in the baseline check) and
`bash scripts/test-architecture.sh` after changing a boundary. Keep CMake source
roots and `scripts/swift-sources.sh` aligned so app builds and regression harnesses
compile the same implementations. Preserve snapshot core compatibility and persisted
encodings during architectural work.
