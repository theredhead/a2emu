#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
stage="$(mktemp -d "${TMPDIR:-/tmp}/a2-dutch-layout.XXXXXX")"
trap 'rm -rf "$stage"' EXIT
# Inspect production layout without activating or displaying windows.
sed -e 's/^@main final class Builder/final class Builder/' \
    -e '/NSApp.activate(ignoringOtherApps: true)/d' \
    -e '/window.makeKeyAndOrderFront(nil)/d' Sources/Builder/Builder.swift > "$stage/Builder.swift"
sed 's/^    private /    /' Sources/Player/ControllerMapping.swift > "$stage/ControllerMapping.swift"
app="$stage/Dutch Layout.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp -R Resources/Localizations/*.lproj "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>CFBundleExecutable</key><string>LayoutTests</string><key>CFBundleIdentifier</key><string>nl.theredhead.a2emu.layout-tests</string><key>CFBundleDevelopmentRegion</key><string>en</string></dict></plist>
PLIST
xcrun swiftc -swift-version 4 -module-cache-path "$stage/cache" \
    Sources/Shared/Intl/*.swift Sources/Shared/PlayerManifest.swift Sources/Shared/PlayerSnapshot.swift \
    Sources/Shared/About.swift Sources/Shared/DiskImageDevice.swift Sources/Builder/BlankDiskImage.swift Sources/Builder/PlayerExporter.swift \
    Sources/Builder/IconEncoder.swift Sources/Builder/IconPicker.swift "$stage/Builder.swift" \
    Sources/Player/KeyboardConfigurationView.swift Sources/Player/JoystickConfigurationView.swift \
    Sources/Player/KeypadConfigurationView.swift "$stage/ControllerMapping.swift" \
    scripts/test-dutch-layout.swift -o "$app/Contents/MacOS/LayoutTests"
"$app/Contents/MacOS/LayoutTests" -AppleLanguages '(nl)' -AppleLocale nl_NL
