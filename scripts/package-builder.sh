#!/bin/bash
# Package prebuilt Intel and Apple Silicon apps into a universal release.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="$repo_root/releases"
case "${1:-}" in
  --output-dir) output_dir="${2:?Provide an output directory}"; shift 2 ;;
  --help|-h) printf 'Usage: %s [--output-dir DIRECTORY]\n' "$0"; exit 0 ;;
esac
if [[ $# -ne 0 ]]; then
  printf 'Unknown argument: %s\n' "$1" >&2
  exit 1
fi
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$repo_root/Sources/Player/Info.plist")"
# Reject stale inputs before replacing any generated release staging files.
for arch in arm64 x86_64; do
  for app in 'Apple II Player.app' 'Apple IIGS Player Builder.app'; do
    built_app="$repo_root/build/release-$arch/$app"
    built_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$built_app/Contents/Info.plist")"
    if [[ "$built_version" != "$version" ]]; then
      printf 'Rebuild stale application: %s\n' "$built_app" >&2
      exit 1
    fi
  done
done
mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd)"
release_stage="$output_dir/Apple-IIGS-Player-Builder-$version-universal"
rm -rf "$release_stage"
mkdir -p "$release_stage"

universal_app() {
  local app_name="$1" destination="$2" executable="${1%.app}"
  ditto "$repo_root/build/release-arm64/$app_name" "$destination"
  lipo -create \
    "$repo_root/build/release-arm64/$app_name/Contents/MacOS/$executable" \
    "$repo_root/build/release-x86_64/$app_name/Contents/MacOS/$executable" \
    -output "$destination/Contents/MacOS/$executable"
  find "$destination/Contents/MacOS" -name '*.d' -type f -delete
}
verify_app() {
  if [[ -f "$1/Contents/Resources/Player-Source.zip" ]]; then
    printf 'Unexpected embedded source archive: %s\n' "$1" >&2
    return 1
  fi
  codesign --verify --deep --strict "$1"
  local architectures
  architectures="$(lipo -archs "$1/Contents/MacOS/$2")"
  for arch in arm64 x86_64; do
    if [[ " $architectures " != *" $arch "* ]]; then
      printf 'Missing %s architecture: %s\n' "$arch" "$1" >&2
      return 1
    fi
  done
}
builder="$release_stage/Apple IIGS Player Builder.app"
universal_app 'Apple IIGS Player Builder.app' "$builder"
resources="$builder/Contents/Resources"
mkdir -p "$resources"
player="$resources/PlayerTemplate.app"
universal_app 'Apple II Player.app' "$player"
rm -f "$player/Contents/Resources/Player-Source.zip"
codesign --force --deep --sign - "$player"
verify_app "$player" 'Apple II Player'
cp "$repo_root/Assets/Builder.icns" "$resources/Builder.icns"
cp "$repo_root/Assets/BuilderIcon.png" "$resources/BuilderIcon.png"
cp "$repo_root/Assets/PlayerIcon.png" "$resources/PlayerIcon.png"
rm -f "$resources/Player-Source.zip"
cp "$repo_root/LICENSE" "$resources/LICENSE.txt"
codesign --force --deep --sign - "$builder"
verify_app "$builder" 'Apple IIGS Player Builder'
cat > "$release_stage/Read me.txt" <<README
Apple IIGS Player Builder $version
macOS 13+, Intel and Apple Silicon. Locally signed, not notarized.

Choose disk images, edit the app name and disk labels, and select available drives.
Assign initial disks and choose the startup slot. A single drive is selected automatically.
Slot 6: 5.25-inch floppy. Slot 5: 3.5-inch floppy. Slot 7: hard disk / SmartPort.
Choose an initial speed and optionally Start in full screen, then Create Player.
Startup Snapshot optionally bundles a saved machine and disk state for every launch;
it restores its captured speed. Clear it to use normal startup.
Drop an existing player on the builder (or File > Open Player) to edit it, then Save.
Quit the player before saving. Its saved disk data and application identity are preserved.

Player menus:
Emulation > Pause/Resume freezes or continues the emulator (also pauses on controller loss).
Emulation > Snapshots saves and restores a dated thumbnail grid of self-contained snapshots.
Snapshots are kept in the player's Application Support/Snapshots directory.
Snapshots require the matching emulator core, ROM, RAM size, and audio sample rate.
Emulation > Speed changes and saves the CPU speed.
Emulation > Disks swaps or ejects images in available drives; hidden for one disk/drive.
View > Save Screenshot uses F3 (or Fn-F3 if macOS reserves F3), without Command/Option.
Screenshots go to Pictures/Apple II Player/<game name> and play the system shutter sound.
View > Resize in Integer Multiples snaps the window size while resizing.
ROM setup is offered if no compatible shared ROM is installed. No firmware ROM is bundled.
ROMs are shared in Application Support/nl.theredhead.a2emu.player/ROMs.
Each player can choose its own ROM through Emulation > Change ROM.

Choose Player Icon searches DuckDuckGo for apple ][ and the first disk name.
Select a result or local image, drag and zoom the square crop, then Use This Crop.
Emulation > Controls configures classic analog joystick or numeric-keypad/Apple-key mappings.
Licenses and credits are included in the player (About > More), with a link to
https://github.com/theredhead/a2emu for the builder and player project.
README
ditto -c -k --sequesterRsrc --keepParent "$release_stage" "$release_stage.zip"
(cd "$output_dir" && shasum -a 256 "$(basename "$release_stage").zip" > "$(basename "$release_stage").sha256")
printf '%s\n' "$release_stage.zip"
