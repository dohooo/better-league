#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

: "${SIGN_IDENTITY:?Set SIGN_IDENTITY to your Developer ID Application identity}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to your notarytool Keychain profile}"
if [ "$SIGN_IDENTITY" = "-" ]; then
    echo 'A release requires a Developer ID Application signature.' >&2
    exit 1
fi

notary_options=(--keychain-profile "$NOTARY_PROFILE")
if [ -n "${NOTARY_KEYCHAIN:-}" ]; then
    notary_options+=(--keychain "$NOTARY_KEYCHAIN")
fi
notarize() {
    local archive="$1" report=".build/notary-$2.json"
    if ! xcrun notarytool submit "$archive" "${notary_options[@]}" --wait --timeout 10m --output-format json > "$report"; then
        cat "$report"
        return 1
    fi
    if [ "$(plutil -extract status raw "$report")" != Accepted ]; then
        cat "$report"
        echo 'Apple did not accept this notarization submission.' >&2
        return 1
    fi
}

./scripts/build.sh
app=".build/Better League.app"
ditto -c -k --keepParent "$app" .build/notarization.zip
notarize .build/notarization.zip app
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

./scripts/package.sh ''
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' resources/Info.plist)
dmg="dist/Better-League-$version.dmg"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$dmg"
notarize "$dmg" dmg
xcrun stapler staple "$dmg"
(cd dist && shasum -a 256 "$(basename "$dmg")") > "$dmg.sha256"
./scripts/verify.sh "$dmg" --notarized
printf 'Verified release: %s\n' "$dmg"
