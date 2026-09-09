#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool Keychain profile}"
if [ "$SIGN_IDENTITY" = "-" ]; then
    echo 'A release requires a Developer ID Application signature.' >&2
    exit 1
fi
./scripts/build.sh
app=".build/Better League.app"
ditto -c -k --keepParent "$app" .build/notarization.zip
xcrun notarytool submit .build/notarization.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

./scripts/package.sh ''
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' resources/Info.plist)
dmg="dist/Better-League-$version.dmg"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$dmg"
xcrun notarytool submit "$dmg" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"

mountpoint=$(mktemp -d "${TMPDIR:-/tmp}/better-league-verify.XXXXXX")
trap 'hdiutil detach "$mountpoint" >/dev/null 2>&1 || true; rmdir "$mountpoint"' EXIT
hdiutil attach "$dmg" -readonly -nobrowse -mountpoint "$mountpoint"
codesign --verify --deep --strict "$mountpoint/Better League.app"
xcrun stapler validate "$mountpoint/Better League.app"
spctl --assess --type execute --verbose=2 "$mountpoint/Better League.app"
shasum -a 256 "$dmg" > "$dmg.sha256"
printf 'Verified release: %s\n' "$dmg"
