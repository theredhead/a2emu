# Swift development baseline

The Apple IIgs Player Builder baseline applies to all first-party Swift in this project. Use the checked-in `.swift-format` and `.swiftlint.yml`. Run `zsh swift-baseline.sh format`, then `zsh swift-baseline.sh check`, relevant tests and the existing app build. Four spaces, a 110-column target, blank lines between methods/logical sections, explicit returns and correctly attached documentation are required. Exclude vendor code and generated copies.

Require readable, well architected code following SOLID design. Keep responsibilities cohesive and dependencies explicit; separate UI, domain rules, persistence and platform adapters. Use narrow interfaces where substitution or ownership needs them, not speculative layers. Focused files and extensions help navigation but do not alone establish separation of responsibilities.

Imported C APIs belong behind native Swift wrappers. Keep raw handles, pointers, callbacks, C constants and cleanup private to the owning adapter. Expose Swift names, values, errors and lifetime semantics. Copy borrowed results before returning them and document thread affinity. Preserve persisted data encodings and user-visible behavior during readability changes.

Preserve unrelated local work. The user authorizes verified readability changes to be committed as `readability refactor round` and pushed to an existing configured origin. Do not invent a remote or stage unrelated files.
