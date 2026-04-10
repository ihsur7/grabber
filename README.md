# Grabber

[![Version 1.0.0](https://img.shields.io/badge/version-1.0.0-0f766e)](https://github.com/ihsur7/grabber/releases)
[![Build Status](https://github.com/ihsur7/grabber/actions/workflows/ci.yml/badge.svg)](https://github.com/ihsur7/grabber/actions/workflows/ci.yml)

Grabber is a macOS menu bar utility for moving the frontmost window by holding a modifier key and dragging the mouse.

Current release target: 1.0.1.

## License

Grabber is intended to be licensed under Apache License 2.0. You can distribute the source and prebuilt releases under the terms of that license, and the app may be sold or offered for free through channels such as the Mac App Store, GitHub, and Homebrew.

## Homebrew Tap

The published Homebrew tap lives in the separate public `ihsur7/homebrew-grabber` repository.

Install with the normal tap flow:

```bash
brew tap ihsur7/grabber
brew install --cask grabber
```

This repo only keeps the tap template in [homebrew/grabber.rb.template](/Users/rushi/Developer/grabber/homebrew/grabber.rb.template). The release workflow renders that template and pushes the real cask into the tap repo automatically.

## Release Packaging

This repository is set up to produce a Homebrew-friendly release zip from the Xcode project.

### Build a release zip locally

```bash
./scripts/package_release.sh 1.0.0
```

The script builds the `grabber` scheme in Release mode, packages `Grabber.app` into a zip, writes a matching SHA-256 file next to it, and renders a tap-ready cask file at `build/release/grabber.rb` from [homebrew/grabber.rb.template](/Users/rushi/Developer/grabber/homebrew/grabber.rb.template).

To build a signed and notarized release locally, export the same environment variables used by CI and then run:

```bash
SIGN_RELEASE=1 \
NOTARIZE_RELEASE=1 \
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_KEY_ID="..." \
NOTARYTOOL_ISSUER_ID="..." \
NOTARYTOOL_KEY_PATH="$HOME/private_keys/AuthKey_XXXX.p8" \
./scripts/package_release.sh 1.0.0
```

### GitHub release workflow

The workflow in [.github/workflows/release.yml](.github/workflows/release.yml) runs the same packaging script when you push a tag that starts with `v` or when you trigger it manually. A tag push publishes a release from that tag. A manual run creates or updates the matching `vX.Y.Z` GitHub Release from the selected commit.

The release workflow now expects signing, notarization, and tap-publishing secrets. Configure these repository secrets before publishing:

1. `BUILD_CERTIFICATE_P12_BASE64`: Base64-encoded Developer ID Application `.p12` certificate.
2. `BUILD_CERTIFICATE_PASSWORD`: Password for that `.p12` file.
3. `BUILD_KEYCHAIN_PASSWORD`: Temporary keychain password used on the GitHub runner.
4. `DEVELOPER_ID_APPLICATION`: Exact signing identity name, such as `Developer ID Application: Your Name (TEAMID)`.
5. `NOTARYTOOL_KEY_ID`: App Store Connect API key ID.
6. `NOTARYTOOL_ISSUER_ID`: App Store Connect API issuer ID.
7. `NOTARYTOOL_PRIVATE_KEY`: Full contents of the `.p8` notary API key.
8. `HOMEBREW_TAP_GITHUB_TOKEN`: Fine-grained GitHub token with contents write access to `ihsur7/homebrew-grabber`.

You can create the certificate in Apple Developer, export it from Keychain Access as `.p12`, and encode it for GitHub with:

```bash
base64 -i developer-id-application.p12 | pbcopy
```

### Release checklist

1. Build locally with `./scripts/package_release.sh 1.0.0`.
2. Tag the release as `v1.0.0` and push it.
3. Confirm the GitHub Release contains `grabber-1.0.0.zip` and `grabber-1.0.0.zip.sha256`.
4. Confirm the workflow pushed the updated cask to your `homebrew-grabber` tap repo.

### Notes for Homebrew users

Grabber requires Accessibility permission to grab and move other app windows. Homebrew can install the app bundle, but the first launch still needs that system permission to be granted.

## Notes for maintainers

The release workflow now fails fast if signing secrets are missing, which prevents shipping an unsigned GitHub Release by accident. Local packaging still works unsigned unless you explicitly set `SIGN_RELEASE=1` or `NOTARIZE_RELEASE=1`.
