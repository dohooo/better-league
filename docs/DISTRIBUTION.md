# Distribution

Better League ships as a universal macOS 26 app in a drag-to-Applications disk image. Its bundle identifier is `com.dohooo.better-league`; keep this identifier and the signing team stable so macOS can recognize updates.

## Local test build

```sh
make dist
make check
```

Outputs:

- `dist/Better-League-0.1.0-local.dmg`
- `dist/Better-League-0.1.0-local.dmg.sha256`

These builds are ad-hoc signed by default and are intended for local testing. They do not carry an Apple notarization ticket. The GitHub build workflow produces the same type of artifact.

## GitHub Actions release

The **Build macOS app** workflow checks every push and pull request without signing secrets. It validates the universal binary, bundle metadata, app signature, DMG structure, and portable checksum.

Configure these repository Actions secrets before the first release:

| Secret | Value |
| --- | --- |
| `APPLE_CERTIFICATE` | Base64-encoded Developer ID Application `.p12`, including its private key and certificate chain |
| `APPLE_CERTIFICATE_PASSWORD` | Password protecting that `.p12` |
| `APPLE_ID` | Apple ID used for notarization |
| `APPLE_PASSWORD` | App-specific password for that Apple ID |
| `APPLE_TEAM_ID` | Developer team matching the signing certificate |

Credentials are imported into a temporary runner keychain and removed at the end of the job. They are never needed by pull-request builds.

Set the version and build number in `resources/Info.plist`, add `docs/releases/VERSION.md`, and push to `main`. After the build passes:

```sh
gh workflow run release.yml --ref main
```

The workflow builds and verifies again, signs and notarizes the app and DMG, and verifies the mounted result. Only then does it create a tag and draft release at the workflow's exact commit. It downloads the uploaded assets and verifies their checksum before publishing the release.

Only run this workflow for a new version. It does not overwrite existing tags or releases. If publication stops after creating a draft, inspect the failed run and draft before retrying.

## Local signed and notarized release

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

A release stops on any failed command or any notarization result other than `Accepted`. Only use the unsuffixed `Better-League-VERSION.dmg` after the entire script succeeds. The local script does not upload anything to GitHub.

## Verify a downloaded release

Put the DMG and its `.sha256` file in the same directory, then run:

```sh
shasum -a 256 -c Better-League-0.1.0.dmg.sha256
```

## Manual acceptance

- Drag the app from the DMG into Applications, launch it, and grant Accessibility.
- Enable recovery from the window and confirm the menu checkmark changes.
- Disable recovery from the menu and confirm the window switch changes.
- Drag the panel by its title. Hide it with Escape or Command-W, reopen it from the menu, and confirm the app never appears in the Dock.
- Quit, relaunch, and confirm the saved switch preference.
- In a match, reproduce the cursor issue and observe the actual recovery. Check chat, shop, display mode, and app switching separately.

Signing and notarization establish distribution integrity. They do not verify in-game behavior.
