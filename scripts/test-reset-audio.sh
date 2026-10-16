#!/bin/bash
# Local Death Sword media and ROM03 are required; no host audio device is needed.
set -euo pipefail
cd "$(dirname "$0")/.."
stage="$(mktemp -d "${TMPDIR:-/tmp}/a2-reset-probe.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
xcrun clang -DMAC -target "$(uname -m)-apple-macosx13.0" \
    -I Vendor/gsplus/gsplus/src -c scripts/tests/AudioResetProbe.c -o "$stage/probe.o"
A2_PLAYER_AUDIO_OBJECT="$stage/probe.o" A2_PLAYER_TEST_SOURCE=scripts/test-reset-audio.swift \
    scripts/test-player-state.sh
