#!/bin/bash
# Build and push the self-contained website image for AMD64 and ARM64 Linux.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$repo_root/Sources/Player/Info.plist")"
"$repo_root/scripts/package-website.sh"
docker buildx build --platform linux/amd64,linux/arm64 \
  --tag "theredhead/a2emu:$version" --tag theredhead/a2emu:latest \
  --label "org.opencontainers.image.version=$version" \
  --push "$repo_root/Website"
