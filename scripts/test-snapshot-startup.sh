#!/bin/bash
# Regression fixture is supplied locally and excluded from Git.
set -euo pipefail
cd "$(dirname "$0")/.."
fixture="${A2_SNAPSHOT_TEST_PLAYER:-TestAssets/Rastan/Rastan.app}"
if [[ ! -f "$fixture/Contents/Resources/Startup.a2snapshot/Machine.state" ]]; then
    printf 'Provide the local Rastan snapshot player in TestAssets/Rastan/Rastan.app or A2_SNAPSHOT_TEST_PLAYER.\n' >&2
    exit 1
fi
A2_PLAYER_TEST_SOURCE=scripts/test-snapshot-startup.swift scripts/test-player-state.sh
