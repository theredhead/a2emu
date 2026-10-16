#!/bin/bash
# Uses locally supplied firmware and media; neither is distributed with the source.
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -f TestAssets/ROMs/Apple-IIGS-ROM03.bin || ! -f TestAssets/ShuffleBoot/Shufflepuck-GSOS.hdv ]]; then
    printf 'Snapshot integration test requires local TestAssets ROM03 and Shufflepuck-GSOS.hdv.\n' >&2
    exit 1
fi
A2_PLAYER_TEST_SOURCE=scripts/test-snapshots.swift scripts/test-player-state.sh
