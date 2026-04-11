# Grabber

[![Release](https://img.shields.io/github/v/release/ihsur7/grabber?display_name=tag&label=release)](https://github.com/ihsur7/grabber/releases)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)](#requirements)

Move any window from anywhere — hold a hotkey and drag.

Grabber is a lightweight macOS menu bar utility that lets you move any window by holding a modifier key and dragging anywhere on its surface. No titlebar required.

## Features

- **Hotkey-driven** — hold any combination of ⌃ ⌥ ⌘ ⇧ and drag to reposition any window
- **Menu bar native** — lives quietly in the menu bar, out of your way
- **Launch at login** — optional, toggled from the popover
- **Auto-update** — checks GitHub Releases and prompts in-app when a new version is available
- **Minimal permissions** — requests only the Accessibility permission it needs; nothing else

## Requirements

- macOS 13 Ventura or later
- Accessibility permission (prompted on first launch)

## Installation

### Homebrew (recommended)

```bash
brew tap ihsur7/grabber
brew install --cask grabber
```

### Manual

Download the latest `grabber-<version>.zip` from [Releases](https://github.com/ihsur7/grabber/releases), unzip, and move `Grabber.app` to your Applications folder.

> **Note:** Grabber requires Accessibility permission to move other app windows. Grant it from **System Settings → Privacy & Security → Accessibility** when prompted on first launch.

## Usage

1. Launch Grabber and click **Grant** in the menu bar popover if prompted for Accessibility permission.
2. Hold your configured modifier key (default: ⌥) and drag anywhere on any window to move it.
3. Customize the modifier key combination from the menu bar popover.

## Development

### Build locally

Open `grabber.xcodeproj` in Xcode and run the `grabber` scheme, or build a release zip from the command line:

```bash
./scripts/package_release.sh <version>
```

This builds the `grabber` scheme in Release configuration, packages `Grabber.app` into a zip, writes a matching SHA-256 file, and renders a tap-ready cask at `build/release/grabber.rb` from [`homebrew/grabber.rb.template`](homebrew/grabber.rb.template).

To produce a signed and notarized build locally:

```bash
SIGN_RELEASE=1 \
NOTARIZE_RELEASE=1 \
DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
NOTARYTOOL_KEY_ID="..." \
NOTARYTOOL_ISSUER_ID="..." \
NOTARYTOOL_KEY_PATH="$HOME/private_keys/AuthKey_XXXX.p8" \
./scripts/package_release.sh <version>
```

Use the local script to validate release output before cutting a tag. Use Xcode Cloud for the signed publish and Homebrew tap update.

## Release workflow

Releases are published automatically from Xcode Cloud when a `v*` tag is pushed. The post-build script at [`ci_scripts/ci_post_xcodebuild.sh`](ci_scripts/ci_post_xcodebuild.sh):

- Packages the Developer ID–signed `Grabber.app` from the Xcode Cloud archive
- Uploads `grabber-<version>.zip` and its SHA-256 to the GitHub Release
- Pushes the rendered cask to [`ihsur7/homebrew-grabber`](https://github.com/ihsur7/homebrew-grabber)
- Retains only the newest 3 releases and their tags (configurable via `RELEASE_RETENTION_COUNT`)

### Xcode Cloud setup

Configure the workflow with:

1. A macOS **Archive** action with the app target's Release signing set to **Developer ID** — the archive must contain a Developer ID signed app so the post-build script can package it directly.
2. A tag-based start condition matching `v*`.

| Variable | Required | Description |
|---|---|---|
| `GITHUB_RELEASE_TOKEN` | Yes | GitHub token with `contents:write` on `ihsur7/grabber` |
| `HOMEBREW_TAP_GITHUB_TOKEN` | Yes | GitHub token with `contents:write` on `ihsur7/homebrew-grabber` |
| `PUBLISH_RELEASE` | Manual runs | Set to `1` for archive runs not triggered by a tag |
| `RELEASE_VERSION` | Manual runs | Version string for archive runs not triggered by a `v<version>` tag |
| `GITHUB_RELEASE_REPO` | No | Defaults to `ihsur7/grabber` |
| `HOMEBREW_TAP_REPO` | No | Defaults to `ihsur7/homebrew-grabber` |
| `RELEASE_RETENTION_COUNT` | No | Releases to keep after publish (default: `3`) |

### Release checklist

1. Run `./scripts/package_release.sh <version>` locally for a preflight check.
2. Tag the release as `v<version>` and push — Xcode Cloud handles signing, packaging, and publishing.
3. Confirm the GitHub Release contains `grabber-<version>.zip` and `grabber-<version>.zip.sha256`.
4. Confirm the Homebrew tap is updated in [`ihsur7/homebrew-grabber`](https://github.com/ihsur7/homebrew-grabber).

## Homebrew tap

The published cask lives in the separate [`ihsur7/homebrew-grabber`](https://github.com/ihsur7/homebrew-grabber) repository. This repo keeps only the template at [`homebrew/grabber.rb.template`](homebrew/grabber.rb.template); the CI script renders and pushes the real cask on each release.

## License

[Apache License 2.0](LICENSE)
