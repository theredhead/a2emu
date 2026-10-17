#!/bin/bash
# Prepare the self-hosted site and its matching universal download.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$repo_root/Sources/Player/Info.plist")"
release_name="Apple-IIGS-Player-Builder-$version-universal"
release_dir="$repo_root/releases/$release_name"
release_zip="$release_dir.zip"
if [[ ! -f "$release_zip" ]]; then
  printf 'Build and package release %s before packaging the website.\n' "$version" >&2
  exit 1
fi
output="$repo_root/Website/dist"
mkdir -p "$output/assets" "$output/downloads"
size="$(du -k "$release_zip" | awk '{printf "%.1f", $1/1024}')"
sed -e "s/__VERSION__/$version/g" -e "s/__SIZE__/$size/g" "$repo_root/Website/index.html" > "$output/index.html"
cp "$repo_root/Website/style.css" "$repo_root/Website/app.js" "$output/"
ditto --norsrc --noextattr "$repo_root/Website/assets" "$output/assets"
cp "$release_zip" "$output/downloads/"
cp "$release_dir.sha256" "$output/downloads/"
rm -f "$output/downloads/"A2Emu-Builder-and-Player-Source-*.zip
cp "$repo_root/LICENSE" "$output/downloads/LICENSE.txt"
printf 'User-agent: *\nAllow: /\nSitemap: https://a2emu.theredhead.nl/sitemap.xml\n' > "$output/robots.txt"
cat > "$output/sitemap.xml" <<'SITEMAP'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"><url><loc>https://a2emu.theredhead.nl/</loc></url></urlset>
SITEMAP
(cd "$repo_root/Website" && ditto --norsrc --noextattr -c -k --keepParent dist "$repo_root/releases/a2emu-website-$version.zip")
printf 'Upload the contents of %s to a2emu.theredhead.nl\n' "$output"
