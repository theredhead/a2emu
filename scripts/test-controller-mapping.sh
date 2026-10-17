#!/bin/bash
# Compile the actual mapping and UI types against the existing macOS deployment target.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
test_stage="$(mktemp -d "${TMPDIR:-/tmp}/a2-controller-test.XXXXXX")"
trap 'rm -rf "$test_stage"' EXIT
xcrun swiftc Sources/Shared/Intl/*.swift -swift-version 4 -target "$(uname -m)-apple-macosx13.0" \
    -module-cache-path "$test_stage/module-cache" \
    Sources/Player/KeyboardConfigurationView.swift Sources/Player/ControllerMapping.swift Sources/Player/JoystickConfigurationView.swift \
    Sources/Player/KeypadConfigurationView.swift scripts/test-controller-mapping.swift \
    -o "$test_stage/controller-tests"
"$test_stage/controller-tests"
