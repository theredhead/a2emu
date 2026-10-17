#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check-localization.py
python3 scripts/test-localization-checks.py
stage="$(mktemp -d "${TMPDIR:-/tmp}/a2-localization-test.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
xcrun swiftc -swift-version 4 -module-cache-path "$stage/cache" \
    Sources/Shared/Intl/*.swift scripts/test-localization.swift -o "$stage/localization-tests"
"$stage/localization-tests" "$@"
