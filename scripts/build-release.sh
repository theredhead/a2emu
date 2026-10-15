#!/bin/bash
# Build both architectures, then package the builder with its player template.
set -euo pipefail
cd "$(dirname "$0")/.."
sdl3_prefix="${SDL3_PREFIX:-/opt/homebrew/opt/sdl3}"
for arch in arm64 x86_64; do
  cmake -G Ninja -B "build/release-$arch" -S . \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_PREFIX_PATH="$sdl3_prefix" \
    "-DCMAKE_Swift_FLAGS=-module-cache-path /tmp/a2-swift-module-cache-$arch"
  cmake --build "build/release-$arch" --target a2emu-player a2emu-builder
done
scripts/package-builder.sh "$@"
