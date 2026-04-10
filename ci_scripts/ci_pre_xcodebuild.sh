#!/usr/bin/env bash
# ci_pre_xcodebuild.sh – Xcode Cloud pre-build hook
#
# Stamps the marketing version in project.pbxproj from the git tag before
# Xcode reads the project, so the built app's CFBundleShortVersionString
# automatically matches the release tag (e.g. v1.2.0 -> 1.2.0).

set -euo pipefail

# Only update when building from a version tag.
TAG="${CI_TAG:-}"
if [[ -z "$TAG" ]]; then
    echo "==> No CI_TAG set; skipping marketing version update"
    exit 0
fi

# Strip any leading 'v' prefix (v1.2.0 -> 1.2.0).
VERSION="${TAG#v}"

echo "==> Setting MARKETING_VERSION to $VERSION (from tag $TAG)"
cd "${CI_PRIMARY_REPOSITORY_PATH}"
xcrun agvtool new-marketing-version "$VERSION"
