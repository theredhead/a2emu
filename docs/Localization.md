# Localization

App text lives in `Resources/Localizations/<language>.lproj`. English (`en`) is the
source language and fallback. Dutch (`nl`) is the first alternative language. Both the builder and its exported player template
bundle these standard resources. macOS chooses the language using the user's
language preferences; there is no separate app language setting.

## Typed text access

Use the relevant class in `Sources/Shared/Intl`, such as `BuilderIntl` or
`SnapshotBrowserIntl`. Literal labels are computed properties. Messages containing
runtime values are methods with named arguments:

```swift
choose.title = builderIntl.chooseDisks
summary.stringValue = builderIntl.diskImagesSelected(count: disks.count)
```

Keep `NSLocalizedString`, format specifiers and formatting inside these classes.
Use complete messages, not concatenated fragments. Each lookup includes an explicit
English fallback for standalone tools/tests and a comment for translators. Update
that fallback and the English resource together. Use stable semantic keys; menu
IDs, preference keys, disk filenames and pause tokens must not depend on translated
text. Keyboard legends and controller badge codes describe the original hardware
and remain unchanged. Their accessibility descriptions can be translated.

Plural messages use `.stringsdict`. Preserve numbered placeholders (for example,
`%1$@` and `%2$ld`) and their types when translating; their order may change.
Translations should retain product names, technical filenames, keyboard shortcuts
and URLs where the comments specify them.

## Adding a language

Copy the English tables into a new language's `.lproj` directory and translate the
values and comments as appropriate. Add the plural categories needed by that
language, retaining `other`. Missing tables or keys fall back to English. CMake
picks up the new resources and packages them in both apps without Xcode-specific
build steps.

Run `scripts/test-localization.sh` for resource/placeholder checks and Foundation
lookup tests. The checks also exercise representative invalid translations. Build
and run both apps in the target language and review menus, dialogs, accessibility
text and long labels; the current manually positioned controls need layout review
as translations are introduced. `scripts/test-dutch-layout.sh` launches a hidden
AppKit test bundle with Dutch selected, checking the builder and controller label
bounds. It requires normal macOS UI services. Do not change historical keycap
legends to make a translation fit.
