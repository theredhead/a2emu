#!/bin/bash
# Requires a configured native build, as described in README.md.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
source scripts/swift-sources.sh
cmake --build build --target a2emu-player a2emu-builder
stage="$(mktemp -d "${TMPDIR:-/tmp}/a2-player-state.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
# Give the harness the entry point while compiling the production AppDelegate unchanged otherwise.
sed '/^@main$/d' Sources/Player/Application/AppDelegate.swift > "$stage/AppDelegate.swift"
cat > "$stage/Bridge.h" <<'BRIDGE'
#include "Bridging-Header.h"
extern word32 g_vbl_count;
extern int g_audio_enable;
void a2_audio_test_enable(void);
void a2_audio_test_report(void);
unsigned long long a2_audio_test_render(int frames);
BRIDGE
xcrun swiftc "${shared_sources[@]}" "${player_support_sources[@]}" "${builder_support_sources[@]}" \
    -swift-version 4 -target "$(uname -m)-apple-macosx13.0" \
    -module-cache-path "$stage/module-cache" -Xcc "-I$repo_root/Sources/Player" \
    -Xcc "-I$repo_root/Vendor/gsplus/gsplus/src" -import-objc-header "$stage/Bridge.h" \
    "$stage/AppDelegate.swift" "${A2_PLAYER_TEST_SOURCE:-scripts/test-player-state.swift}" \
    build/CMakeFiles/a2emu-player.dir/Sources/Player/EmulatorReset.c.o \
    build/CMakeFiles/a2emu-player.dir/Sources/Player/HIDGamepad.c.o \
    "${A2_PLAYER_AUDIO_OBJECT:-build/CMakeFiles/a2emu-player.dir/Sources/SnapshotCore/MacSnapshotAudio.c.o}" \
    build/Vendor/gsplus/gsplus/src/libgsplus_core.a \
    -framework Cocoa -framework GameController -framework IOKit \
    -framework AudioToolbox -framework CoreAudio -framework AudioUnit -o "$stage/player-state-tests"
"$stage/player-state-tests"
