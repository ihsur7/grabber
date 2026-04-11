#!/usr/bin/env bash
# ci_pre_xcodebuild.sh – Xcode Cloud pre-build hook
#
# Stamps Config/Version.xcconfig from the git tag before Xcode reads the
# project, so the built app's CFBundleShortVersionString automatically matches
# the release tag (e.g. v1.2.0 -> 1.2.0).

set -euo pipefail

log() {
    echo "==> $*"
}

update_version_config() {
    local version_config="$1"
    local version="$2"

    /usr/bin/python3 - "$version_config" "$version" <<'PY'
from pathlib import Path
import sys

config_path = Path(sys.argv[1])
version = sys.argv[2]

lines = []
if config_path.exists():
    lines = config_path.read_text(encoding="utf-8").splitlines()

new_lines = []
updated = False
for line in lines:
    if line.startswith("MARKETING_VERSION = "):
        new_lines.append(f"MARKETING_VERSION = {version}")
        updated = True
    else:
        new_lines.append(line)

if not updated:
    if not new_lines:
        new_lines.append("// Auto-updated by ci_scripts/ci_pre_xcodebuild.sh")
    new_lines.append(f"MARKETING_VERSION = {version}")

config_path.write_text("\n".join(new_lines) + "\n", encoding="utf-8")
PY
}

main() {
    local version_config version source

    version_config="${CI_PRIMARY_REPOSITORY_PATH}/Config/Version.xcconfig"
    if [[ ! -f "$version_config" ]]; then
        echo "version config not found: $version_config" >&2
        exit 1
    fi

    version="${RELEASE_VERSION:-}"
    source="RELEASE_VERSION"
    if [[ -z "$version" ]]; then
        version="${CI_TAG:-}"
        source="CI_TAG"
    fi

    if [[ -z "$version" ]]; then
        log "No RELEASE_VERSION or CI_TAG set; skipping marketing version update"
        exit 0
    fi

    version="${version#v}"
    log "Setting MARKETING_VERSION to $version (from $source)"
    update_version_config "$version_config" "$version"
}

main "$@"
