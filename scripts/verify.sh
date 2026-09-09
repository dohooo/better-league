#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

dmg="${1:?Usage: verify.sh path/to/image.dmg [--notarized]}"
mode="${2:-}"
case "$mode" in ''|--notarized) ;; *) echo 'Unknown verification mode' >&2; exit 1 ;; esac

plutil -lint resources/Info.plist
bash -n scripts/build.sh scripts/package.sh scripts/release.sh scripts/verify.sh
zsh -n bin/lol
(cd "$(dirname "$dmg")" && shasum -a 256 -c "$(basename "$dmg").sha256")
hdiutil verify "$dmg"
if [ "$mode" = --notarized ]; then
    codesign --verify --strict "$dmg"
    xcrun stapler validate "$dmg"
fi

mountpoint=$(mktemp -d "${TMPDIR:-/tmp}/better-league-verify.XXXXXX")
trap 'hdiutil detach "$mountpoint" >/dev/null 2>&1 || true; rmdir "$mountpoint" 2>/dev/null || true' EXIT
hdiutil attach "$dmg" -readonly -nobrowse -mountpoint "$mountpoint"
app="$mountpoint/Better League.app"
cmp resources/Info.plist "$app/Contents/Info.plist"
codesign --verify --deep --strict "$app"
lipo "$app/Contents/MacOS/BetterLeague" -verify_arch arm64 x86_64
test "$(readlink "$mountpoint/Applications")" = /Applications
if [ "$mode" = --notarized ]; then
    xcrun stapler validate "$app"
    spctl --assess --type execute --verbose=2 "$app"
fi
hdiutil detach "$mountpoint"
rmdir "$mountpoint"
trap - EXIT
printf 'Verified %s\n' "$dmg"
