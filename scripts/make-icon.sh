#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_image="${1:-Assets/PlayerIcon.png}"
icon_name="${2:-Player}"
mkdir -p "build/$icon_name.iconset"
xcrun swiftc -parse-as-library -module-cache-path build/icon-module-cache \
  scripts/make-icon.swift -o build/make-icon
build/make-icon "$source_image" "build/$icon_name.iconset"
iconutil -c icns "build/$icon_name.iconset" -o "Assets/$icon_name.icns"
