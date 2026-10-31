#!/bin/bash
# Keep one layout tool; SwiftLint only checks the focused quality rules.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
case "${1:-check}" in
    format)
        zsh swift-baseline.sh format
        ;;
    check)
        zsh swift-baseline.sh check
        ;;
    test)
        python3 scripts/test-swift-style.py
        ;;
    *)
        printf 'Usage: %s [format|check|test]\n' "$0" >&2
        exit 2
        ;;
esac
