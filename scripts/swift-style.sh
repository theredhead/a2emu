#!/bin/bash
# Keep one layout tool; SwiftLint only checks the focused quality rules.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
case "${1:-check}" in
    format)
        xcrun swift-format format --configuration .swift-format --in-place --recursive Sources
        ;;
    check)
        xcrun swift-format lint --configuration .swift-format --strict --recursive Sources
        swiftlint lint --config .swiftlint.yml --strict --no-cache
        ;;
    test)
        python3 scripts/test-swift-style.py
        ;;
    *)
        printf 'Usage: %s [format|check|test]\n' "$0" >&2
        exit 2
        ;;
esac
