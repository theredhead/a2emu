#!/bin/bash
# Test native and direct-input selection without physical controller hardware.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
test_stage="$(mktemp -d "${TMPDIR:-/tmp}/a2-selection-test.XXXXXX")"
trap 'rm -rf "$test_stage"' EXIT
test_target="$(uname -m)-apple-macosx13.0"
xcrun clang -target "$test_target" -c scripts/tests/ControllerSelectionStubs.c -o "$test_stage/stubs.o"
xcrun swiftc -swift-version 4 -target "$test_target" -module-cache-path "$test_stage/module-cache" \
    -Xcc "-I$repo_root/Sources/Player" -import-objc-header scripts/tests/ControllerSelectionBridge.h \
    Sources/Player/ControllerHardware.swift Sources/Player/GamepadInput.swift Sources/Player/KeyboardConfigurationView.swift Sources/Player/ControllerMapping.swift \
    Sources/Player/JoystickConfigurationView.swift Sources/Player/KeypadConfigurationView.swift \
    scripts/tests/ControllerSelectionTests.swift "$test_stage/stubs.o" -o "$test_stage/selection-tests"
"$test_stage/selection-tests"

xcrun clang -target "$test_target" scripts/tests/HIDInventoryTests.c \
    -framework IOKit -framework CoreFoundation -o "$test_stage/hid-inventory-tests"
"$test_stage/hid-inventory-tests"
