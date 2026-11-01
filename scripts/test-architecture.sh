#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/swift-sources.sh
stage="$(mktemp -d "${TMPDIR:-/tmp}/a2-architecture.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 4 -module-cache-path "$stage/cache" \
  "${shared_sources[@]}" "${builder_support_sources[@]}" \
  Sources/Player/Domain/Session/EmulationPause.swift \
  Sources/Player/Infrastructure/Storage/PlayerStorage.swift \
  Sources/Player/Infrastructure/Storage/PlayerConfigurationStore.swift \
  Sources/Player/Infrastructure/Firmware/ROMLibrary.swift Sources/Player/Infrastructure/Firmware/ROMDownload.swift \
  scripts/test-architecture.swift -o "$stage/checks"
"$stage/checks"
