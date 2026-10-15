#!/bin/bash
# Bundle corresponding source and generic artwork, without firmware or media.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_archive="${1:-$repo_root/build/Player-Source.zip}"
mkdir -p "$(dirname "$source_archive")"
source_archive="$(cd "$(dirname "$source_archive")" && pwd)/$(basename "$source_archive")"
source_stage="$(mktemp -d "${TMPDIR:-/tmp}/a2-source.XXXXXX")"
trap 'rm -rf "$source_stage"' EXIT
source_root="$source_stage/Apple-II-Player-Source"
mkdir -p "$source_root/Assets" "$source_root/Vendor"
for name in .gitignore .swift-format .swiftlint.yml README.md CMakeLists.txt SOURCE-README.md LICENSE MODIFICATIONS.txt Sources scripts Vendor/gsplus; do
  if [[ ! -e "$repo_root/$name" ]]; then
    printf 'Missing source dependency: %s\n' "$name" >&2
    exit 1
  fi
  rsync -a --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' \
    --exclude='*.pyo' --exclude='.DS_Store' \
    "$repo_root/$name" "$source_root/$(dirname "$name")/"
done
for name in Player.icns PlayerIcon.png Builder.icns BuilderIcon.png Builder-Icon-Prompt.txt; do
  cp "$repo_root/Assets/$name" "$source_root/Assets/$name"
done
cat > "$source_root/BUILDING.txt" <<'BUILDING'
Requires Xcode command line tools, CMake, Ninja and SDL3.
Run scripts/build-release.sh to build and package both architectures.
Set SDL3_PREFIX if SDL3 is installed outside /opt/homebrew/opt/sdl3.
The template contains no disk or firmware; the builder supplies selected media.
GSplus revision: 41e71031debbde98e66ea5c5c67498e9b4726a6d.
BUILDING
ditto --norsrc --noextattr -c -k --keepParent "$source_root" "$source_archive"
printf '%s\n' "$source_archive"
