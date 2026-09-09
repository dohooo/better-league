#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

app=".build/Better League.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp resources/Info.plist "$app/Contents/Info.plist"

for arch in arm64 x86_64; do
    xcrun swiftc -O -parse-as-library -target "$arch-apple-macosx14.0" \
        src/Core/*.swift src/App/*.swift -o ".build/BetterLeague-$arch"
done
xcrun lipo -create .build/BetterLeague-arm64 .build/BetterLeague-x86_64 -output "$app/Contents/MacOS/BetterLeague"
xcrun swift scripts/generate-icon.swift .build/AppIcon.iconset
xcrun iconutil -c icns .build/AppIcon.iconset -o "$app/Contents/Resources/AppIcon.icns"

identity="${SIGN_IDENTITY:--}"
if [ "$identity" = "-" ]; then
    codesign --force --sign - "$app"
else
    codesign --force --options runtime --timestamp --sign "$identity" "$app"
fi
codesign --verify --deep --strict "$app"
printf 'Built %s\n' "$app"
