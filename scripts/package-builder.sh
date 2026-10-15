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
  for app in 'Apple II Player.app' 'Apple II Wrapper Builder.app'; do
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
release_stage="$output_dir/Apple-II-Wrapper-Builder-$version-universal"
rm -rf "$release_stage"
mkdir -p "$release_stage"
"$repo_root/scripts/bundle-source.sh"

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
builder="$release_stage/Apple II Wrapper Builder.app"
universal_app 'Apple II Wrapper Builder.app' "$builder"
resources="$builder/Contents/Resources"
mkdir -p "$resources"
player="$resources/PlayerTemplate.app"
universal_app 'Apple II Player.app' "$player"
cp "$repo_root/build/Player-Source.zip" "$player/Contents/Resources/Player-Source.zip"
codesign --force --deep --sign - "$player"
verify_app "$player" 'Apple II Player'
cp "$repo_root/Assets/Builder.icns" "$resources/Builder.icns"
cp "$repo_root/LICENSE" "$resources/LICENSE.txt"
codesign --force --deep --sign - "$builder"
verify_app "$builder" 'Apple II Wrapper Builder'
cat > "$release_stage/Read me.txt" <<README
Apple II Wrapper Builder $version
macOS 13+, Intel and Apple Silicon. Locally signed, not notarized.

Choose disk images, edit the app name and disk labels, and select available drives.
Assign initial disks and choose the startup slot. A single drive is selected automatically.
Slot 6: 5.25-inch floppy. Slot 5: 3.5-inch floppy. Slot 7: hard disk / SmartPort.
Choose an initial speed and optionally Start in full screen, then Create Player.

Player menus:
Emulation > Speed changes and saves the CPU speed.
Emulation > Disks swaps or ejects images in available drives; hidden for one disk/drive.
View > Resize in Integer Multiples snaps the window size while resizing.
ROM setup is offered on first launch. No firmware ROM is bundled in the template.

Choose Player Icon searches DuckDuckGo for apple ][ and the first disk name.
Select a result or local image, drag and zoom the square crop, then Use This Crop.
Gamepad mapping remains pending.
GPL source, licenses and credits are embedded in the player (About > More).
README
ditto -c -k --sequesterRsrc --keepParent "$release_stage" "$release_stage.zip"
(cd "$output_dir" && shasum -a 256 "$(basename "$release_stage").zip" > "$(basename "$release_stage").sha256")
printf '%s\n' "$release_stage.zip"
