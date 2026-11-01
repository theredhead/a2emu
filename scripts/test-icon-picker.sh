#!/bin/bash
# Requires macOS WebKit UI services; uses an in-memory image instead of live search results.
set -euo pipefail
cd "$(dirname "$0")/.."
test_stage=$(mktemp -d)
trap 'rm -rf "$test_stage"' EXIT
# Expose picker internals only in the test copy.
sed -e 's/private //g' -e 's/iconPickerIntl/testIconPickerIntl/g' Sources/Builder/Presentation/Icons/IconPicker.swift > "$test_stage/IconPicker.swift"
xcrun swiftc Sources/Shared/Intl/*.swift -swift-version 4 -module-cache-path "$test_stage/cache" \
    Sources/Builder/Infrastructure/Icons/ArtworkLoader.swift Sources/Builder/Presentation/Icons/SquareCropView.swift "$test_stage/IconPicker.swift" scripts/test-icon-picker.swift -o "$test_stage/test"
"$test_stage/test"
