#!/bin/bash
# Requires macOS WebKit UI services; uses an in-memory image instead of live search results.
set -euo pipefail
cd "$(dirname "$0")/.."
test_stage=$(mktemp -d)
trap 'rm -rf "$test_stage"' EXIT
# Expose picker internals only in the test copy.
sed 's/private //g' Sources/Builder/IconPicker.swift > "$test_stage/IconPicker.swift"
xcrun swiftc -swift-version 4 -module-cache-path "$test_stage/cache" \
    "$test_stage/IconPicker.swift" scripts/test-icon-picker.swift -o "$test_stage/test"
"$test_stage/test"
