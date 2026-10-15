#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_image="${1:-Assets/PlayerIcon.png}"
icon_name="${2:-Player}"
mkdir -p "build/$icon_name.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$source_image" --out "build/$icon_name.iconset/icon_${size}x${size}.png" >/dev/null
  retina=$((size * 2))
  sips -z "$retina" "$retina" "$source_image" --out "build/$icon_name.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "build/$icon_name.iconset" -o "Assets/$icon_name.icns"
