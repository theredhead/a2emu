#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
release_root="$PWD/releases/Apple-II-Player-0.3.0-universal"
mkdir -p "$release_root"
python3 scripts/bundle-source.py
for arch in arm64 x86_64; do
  cmake -G Ninja -B "build/release-$arch" -S . -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="$arch" -DCMAKE_PREFIX_PATH=/opt/homebrew/opt/sdl3 "-DCMAKE_Swift_FLAGS=-module-cache-path /tmp/a2-swift-module-cache-$arch"
  cmake --build "build/release-$arch" --target a2emu-player
done
ditto 'build/release-arm64/Apple II Player.app' "$release_root/Apple II Player.app"
lipo -create 'build/release-arm64/Apple II Player.app/Contents/MacOS/Apple II Player' 'build/release-x86_64/Apple II Player.app/Contents/MacOS/Apple II Player' -output "$release_root/Apple II Player.app/Contents/MacOS/Apple II Player"
codesign --force --sign - "$release_root/Apple II Player.app"
codesign --verify --deep --strict "$release_root/Apple II Player.app"
lipo -archs "$release_root/Apple II Player.app/Contents/MacOS/Apple II Player"
ditto -c -k --sequesterRsrc --keepParent "$release_root" "$release_root.zip"
