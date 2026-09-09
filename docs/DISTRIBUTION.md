# Distribution

Better League ships as a universal macOS 26 app in a drag-to-Applications disk image. Its bundle identifier is `com.dohooo.better-league`; keep this identifier and the signing team stable so macOS can recognize updates.

## Local test build

```sh
make dist
```

Outputs:

- `dist/Better-League-0.1.0-local.dmg`
- `dist/Better-League-0.1.0-local.dmg.sha256`

These builds are ad-hoc signed by default and are intended for local testing. They do not carry an Apple notarization ticket. The GitHub build workflow produces the same type of artifact.

## Signed and notarized release

Requires a valid **Developer ID Application** certificate with its private key and an Apple notarization account. The release script follows Apple's [notarization requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

Store notarization credentials in Keychain using the interactive command. Do not put passwords or signing keys in the repository:

```sh
xcrun notarytool store-credentials better-league
```

Update `CFBundleShortVersionString` and `CFBundleVersion` in `resources/Info.plist`, then run:

```sh
SIGN_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
NOTARY_PROFILE=better-league \
make release
```

The script:

1. Compiles both architectures and signs the app with hardened runtime and a secure timestamp.
2. Submits the app to Apple, staples its ticket, and checks Gatekeeper acceptance.
3. Packages a DMG, signs and notarizes it, and staples its ticket.
4. Mounts the final DMG read-only and rechecks the app's signature, ticket, and Gatekeeper acceptance.
5. Writes the final DMG's SHA-256 checksum.

A release stops on any failed command. Only use the unsuffixed `Better-League-VERSION.dmg` after the entire script succeeds. The script does not upload anything to GitHub.

## Publish to the private repository

Create a draft release for review after local verification:

```sh
gh release create v0.1.0 \
  dist/Better-League-0.1.0.dmg \
  dist/Better-League-0.1.0.dmg.sha256 \
  --draft --title 'Better League 0.1.0' \
  --notes 'Initial macOS menu bar app with cursor recovery controls.'
```

Private repository releases are only available to people with repository access. Review the draft and its installed app before publishing it.

## Manual acceptance

- Drag the app from the DMG into Applications, launch it, and grant Accessibility.
- Enable recovery from the window and confirm the menu checkmark changes.
- Disable recovery from the menu and confirm the window switch changes.
- Drag the panel by its title. Hide it with Escape or Command-W, reopen it from the menu, and confirm the app never appears in the Dock.
- Quit, relaunch, and confirm the saved switch preference.
- In a match, reproduce the cursor issue and observe the actual recovery. Check chat, shop, display mode, and app switching separately.

Signing and notarization establish distribution integrity. They do not verify in-game behavior.
