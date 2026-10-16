#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc -module-cache-path "$test_dir/cache" Sources/Builder/DiskImageDevice.swift \
    scripts/test-disk-image-device.swift -o "$test_dir/test"
"$test_dir/test"
sed 's/^@main final class Builder/final class Builder/' Sources/Builder/Builder.swift > "$test_dir/Builder.swift"
xcrun swiftc -swift-version 4 -module-cache-path "$test_dir/cache" \
    "$test_dir/Builder.swift" Sources/Builder/DiskImageDevice.swift \
    Sources/Builder/PlayerExporter.swift Sources/Builder/IconPicker.swift Sources/Builder/IconEncoder.swift \
    Sources/Shared/About.swift Sources/Shared/PlayerManifest.swift Sources/Shared/PlayerSnapshot.swift \
    scripts/test-builder-disk-selection.swift -o "$test_dir/builder-test"
"$test_dir/builder-test"
