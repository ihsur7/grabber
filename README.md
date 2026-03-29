# Grabber

[![Version 1.0.0](https://img.shields.io/badge/version-1.0.0-0f766e)](homebrew/grabber.rb)
[![Build Status](https://github.com/ihsur7/grabber/actions/workflows/ci.yml/badge.svg)](https://github.com/ihsur7/grabber/actions/workflows/ci.yml)

Grabber is a macOS menu bar utility for moving the frontmost window by holding a modifier key and dragging the mouse.

Current release target: 1.0.0.

## License

Grabber is intended to be licensed under Apache License 2.0. You can distribute the source and prebuilt releases under the terms of that license, and the app may be sold or offered for free through channels such as the Mac App Store, GitHub, and Homebrew.

## Homebrew Tap

The cask is named `grabber`, and the tap is the namespace. That is why the install flow is:

```bash
brew tap ihsur/grabber
brew install --cask grabber
```

If you publish from your own tap, place the cask at `Casks/grabber.rb` in a repo named like `homebrew-grabber`.

## Release Packaging

This repository is set up to produce a Homebrew-friendly release zip from the Xcode project.

### Build a release zip locally

```bash
./scripts/package_release.sh 1.0.0
```

The script builds the `grabber` scheme in Release mode, packages `grabber.app` into a zip, writes a matching SHA-256 file next to it, and updates [homebrew/grabber.rb](homebrew/grabber.rb) with the new checksum.

### GitHub release workflow

The workflow in [.github/workflows/release.yml](.github/workflows/release.yml) runs the same packaging script when you push a tag that starts with `v` or when you trigger it manually.

### Release checklist

1. Build locally with `./scripts/package_release.sh 1.0.0`.
2. Commit the updated checksum in [homebrew/grabber.rb](homebrew/grabber.rb).
3. Tag the release as `v1.0.0` and push it.
4. Publish or update the cask in your tap repo.

### Notes for Homebrew users

Grabber requires Accessibility permission to grab and move other app windows. Homebrew can install the app bundle, but the first launch still needs that system permission to be granted.
