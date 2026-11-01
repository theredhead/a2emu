#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/swift-sources.sh
stage="$(mktemp -d "${TMPDIR:-/tmp}/a2-dutch-layout.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
# Inspect production layout without activating or displaying windows.
sed -e 's/^@main final class Builder/final class Builder/' \
    -e '/NSApp.activate(ignoringOtherApps: true)/d' \
    -e '/window.makeKeyAndOrderFront(nil)/d' Sources/Builder/Application/Builder.swift > "$stage/Builder.swift"
sed 's/^    private /    /' Sources/Player/Presentation/Controls/ControllerMappingPanel.swift > "$stage/ControllerMappingPanel.swift"
layout_controller_sources=()
for source in "${controller_sources[@]}"; do
  [[ "$source" == */ControllerMappingPanel.swift ]] || layout_controller_sources+=("$source")
done
app="$stage/Dutch Layout.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp -R Resources/Localizations/*.lproj "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>LayoutTests</string><key>CFBundleIdentifier</key><string>nl.theredhead.a2emu.layout-tests</string><key>CFBundleDevelopmentRegion</key><string>en</string></dict></plist>
PLIST
xcrun swiftc -swift-version 4 -module-cache-path "$stage/cache" \
    "${shared_sources[@]}" "${builder_support_sources[@]}" "${layout_controller_sources[@]}" \
    "$stage/Builder.swift" "$stage/ControllerMappingPanel.swift" scripts/test-dutch-layout.swift \
    -o "$app/Contents/MacOS/LayoutTests"
"$app/Contents/MacOS/LayoutTests" -AppleLanguages '(nl)' -AppleLocale nl_NL
