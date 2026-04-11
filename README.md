# Grabber

[![Releases](https://img.shields.io/github/v/release/ihsur7/grabber?display_name=tag&label=release)](https://github.com/ihsur7/grabber/releases)

Grabber is a macOS menu bar utility for moving the frontmost window by holding a modifier key and dragging the mouse.

## License

Grabber is intended to be licensed under Apache License 2.0. You can distribute the source and prebuilt releases under the terms of that license, and the app may be sold or offered for free through channels such as the Mac App Store, GitHub, and Homebrew.

## Homebrew Tap

The published Homebrew tap lives in the separate public `ihsur7/homebrew-grabber` repository.

Install with the normal tap flow:

```bash
brew tap ihsur7/grabber
brew install --cask grabber
```

This repo only keeps the tap template in [homebrew/grabber.rb.template](homebrew/grabber.rb.template). The Xcode Cloud release script renders that template and pushes the real cask into the tap repo automatically.

## Release Packaging

This repository is set up to produce a Homebrew-friendly release zip from the Xcode project.

### Build a release zip locally

```bash
./scripts/package_release.sh <version>
```

The script builds the `grabber` scheme in Release mode, overrides the app's release version from the version argument you pass in, packages `Grabber.app` into a zip, writes a matching SHA-256 file next to it, and renders a tap-ready cask file at `build/release/grabber.rb` from [homebrew/grabber.rb.template](homebrew/grabber.rb.template). It can also package an already-exported app bundle, which is how Xcode Cloud reuses the same logic after an archive build.

To build a signed and notarized release locally, export the same signing inputs your Xcode Cloud archive uses and then run:

```bash
SIGN_RELEASE=1 \
NOTARIZE_RELEASE=1 \
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_KEY_ID="..." \
NOTARYTOOL_ISSUER_ID="..." \
NOTARYTOOL_KEY_PATH="$HOME/private_keys/AuthKey_XXXX.p8" \
./scripts/package_release.sh <version>
```

### Xcode Cloud release workflow

This repository now publishes signed macOS releases from Xcode Cloud. The custom post-build script at [ci_scripts/ci_post_xcodebuild.sh](ci_scripts/ci_post_xcodebuild.sh) runs after a successful macOS archive action, packages the exported `Grabber.app`, uploads `grabber-<version>.zip` and `grabber-<version>.zip.sha256` to the matching GitHub Release, and updates the `ihsur7/homebrew-grabber` tap.

Configure your Xcode Cloud workflow with:

1. A macOS `Archive` action. Xcode Cloud may expose only `None`, `TestFlight (Internal Testing Only)`, and `App Store Connect` here for macOS.
2. The app target's `Release` signing configuration set to `Developer ID` in Xcode, so the archive contains a Developer ID signed app that the post-build script can package.
3. A tag-based start condition for `v*` if you want tagging to trigger publishing automatically.
4. Secret environment variable `GITHUB_RELEASE_TOKEN`: GitHub token with `contents:write` access to `ihsur7/grabber`.
5. Secret environment variable `HOMEBREW_TAP_GITHUB_TOKEN`: GitHub token with `contents:write` access to `ihsur7/homebrew-grabber`.
6. Optional environment variable `GITHUB_RELEASE_REPO`: defaults to `ihsur7/grabber`.
7. Optional environment variable `HOMEBREW_TAP_REPO`: defaults to `ihsur7/homebrew-grabber`.
8. Optional environment variable `PUBLISH_RELEASE=1`: required for manual archive runs that are not started from a tag.
9. Optional environment variable `RELEASE_VERSION=<version>`: required for manual archive runs that are not started from a `v<version>` tag.

For tagged archive builds, the script derives the release version from the tag automatically. For manual archive builds, set both `PUBLISH_RELEASE=1` and `RELEASE_VERSION=<version>` in the workflow environment.

### Local preflight vs Xcode Cloud publish

Use the local packaging script when you want to validate the release output before cutting a tag. Use Xcode Cloud when you want the signed release published and the Homebrew tap updated.

If you still need to create a Developer ID certificate for local packaging, you can export it from Keychain Access as `.p12` and encode it with:

```bash
base64 -i developer-id-application.p12 | pbcopy
```

### Release checklist

1. Build locally with `./scripts/package_release.sh <version>` if you want a preflight check.
2. Tag the release as `v<version>` and push it so the Xcode Cloud archive workflow runs.
3. Confirm the Xcode Cloud build exported a Developer ID signed app and completed the post-build publish step.
4. Confirm the GitHub Release contains `grabber-<version>.zip` and `grabber-<version>.zip.sha256`.
5. Confirm the workflow pushed the updated cask to your `homebrew-grabber` tap repo.

### Notes for Homebrew users

Grabber requires Accessibility permission to grab and move other app windows. Homebrew can install the app bundle, but the first launch still needs that system permission to be granted.

## Notes for maintainers

GitHub Actions no longer builds or publishes the app in this repository. Local packaging still works unsigned unless you explicitly set `SIGN_RELEASE=1` or `NOTARIZE_RELEASE=1`, and signed release publishing now depends on the Xcode Cloud archive workflow being configured correctly.
