#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/swift-sources.sh
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc Sources/Shared/Intl/*.swift -module-cache-path "$test_dir/cache" Sources/Shared/Infrastructure/Media/DiskImageDevice.swift Sources/Builder/Infrastructure/Disks/BlankDiskImage.swift Sources/Builder/Domain/BootReadiness.swift Sources/Shared/Domain/Player/PlayerManifest.swift Sources/Builder/Infrastructure/Disks/DiskBootability.swift Sources/Builder/Domain/Media/ProDOSBootLoader.swift \
    scripts/test-disk-image-device.swift -o "$test_dir/test"
"$test_dir/test"
sed 's/^@main final class Builder/final class Builder/' Sources/Builder/Application/Builder.swift > "$test_dir/Builder.swift"
# Record import errors so mixed-drop failures can be checked without a modal alert.
python3 - "$test_dir/Builder.swift" <<'PYTHON'
import sys
path = sys.argv[1]
source = open(path).read()
start = source.index('    func showError(_ message: String) {')
source = source[:start] + '    func showError(_ message: String) { dropErrors.append(message) }\n}\n'
open(path, 'w').write(source)
PYTHON
xcrun swiftc "${shared_sources[@]}" "${builder_support_sources[@]}" -swift-version 4 -module-cache-path "$test_dir/cache" \
    "$test_dir/Builder.swift" scripts/test-builder-disk-selection.swift -o "$test_dir/builder-test"

"$test_dir/builder-test"
