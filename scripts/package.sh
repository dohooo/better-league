#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' resources/Info.plist)
suffix="${1--local}"
app=".build/Better League.app"
staging=$(mktemp -d "${TMPDIR:-/tmp}/better-league-dmg.XXXXXX")
trap 'rm -rf "$staging"' EXIT
mkdir -p dist
ditto "$app" "$staging/Better League.app"
ln -s /Applications "$staging/Applications"
dmg="dist/Better-League-$version$suffix.dmg"
hdiutil create -volname 'Better League' -srcfolder "$staging" -ov -format UDZO "$dmg"
shasum -a 256 "$dmg" > "$dmg.sha256"
printf 'Packaged %s\n' "$dmg"
