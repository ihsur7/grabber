#!/usr/bin/env bash

set -euo pipefail

log() {
  echo "==> $*"
}

bool_env() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|on|ON)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

require_env() {
  local name="$1"

  if [[ -z "${!name:-}" ]]; then
    echo "required environment variable not set: $name" >&2
    exit 1
  fi
}

find_archive_app_path() {
  local archive_path="$1"
  local app_path

  if [[ -d "$archive_path" && "$archive_path" == *.app ]]; then
    printf '%s\n' "$archive_path"
    return 0
  fi

  if [[ -d "$archive_path/Products/Applications" ]]; then
    app_path="$(find "$archive_path/Products/Applications" -maxdepth 1 -type d -name '*.app' | head -n 1)"
    if [[ -n "$app_path" ]]; then
      printf '%s\n' "$app_path"
      return 0
    fi
  fi

  app_path="$(find "$archive_path" -maxdepth 4 -type d -name '*.app' | head -n 1)"
  if [[ -n "$app_path" ]]; then
    printf '%s\n' "$app_path"
    return 0
  fi

  return 1
}

export_developer_id_app() {
  local archive_path="$1"
  local export_dir export_options_plist app_path

  export_dir="$(mktemp -d)/grabber_devid_export"
  export_options_plist="$(dirname "$0")/ExportOptions.plist"

  if [[ ! -f "$export_options_plist" ]]; then
    echo "ExportOptions.plist not found at $export_options_plist" >&2
    return 1
  fi

  log "Exporting archive for Developer ID distribution from $archive_path ..."
  if ! xcodebuild -exportArchive \
      -archivePath "$archive_path" \
      -exportPath "$export_dir" \
      -exportOptionsPlist "$export_options_plist" \
      -allowProvisioningUpdates; then
    echo "xcodebuild -exportArchive failed" >&2
    return 1
  fi

  app_path="$(find "$export_dir" -maxdepth 1 -type d -name '*.app' | head -n 1)"
  if [[ -n "$app_path" ]]; then
    log "Developer ID export succeeded: $app_path"
    printf '%s\n' "$app_path"
    return 0
  fi

  echo "No .app found in export directory: $export_dir" >&2
  return 1
}

resolve_app_path() {
  local developer_id_path archive_path app_path

  developer_id_path="${CI_DEVELOPER_ID_SIGNED_APP_PATH:-}"
  if [[ -n "$developer_id_path" && -d "$developer_id_path" ]]; then
    printf '%s\n' "$developer_id_path"
    return 0
  fi

  archive_path="${CI_ARCHIVE_PATH:-}"
  if [[ -n "$archive_path" && -d "$archive_path" ]]; then
    log "CI_DEVELOPER_ID_SIGNED_APP_PATH is unavailable; exporting archive for Developer ID distribution"
    app_path="$(export_developer_id_app "$archive_path" || true)"
    if [[ -n "$app_path" ]]; then
      printf '%s\n' "$app_path"
      return 0
    fi
  fi

  return 1
}

validate_developer_id_signing() {
  local app_path="$1"
  local codesign_output authority_line

  require_command codesign

  codesign_output="$(codesign -dvv "$app_path" 2>&1 || true)"
  if grep -Fq 'Authority=Developer ID Application' <<< "$codesign_output"; then
    log "Verified Developer ID signing on $(basename "$app_path")"
    return 0
  fi

  authority_line="$(printf '%s\n' "$codesign_output" | awk -F= '/Authority=/{print $2; exit}')"
  if [[ -n "$authority_line" ]]; then
    echo "resolved archive app is signed with '$authority_line', not Developer ID Application; update the Release target signing certificate in Xcode to Developer ID" >&2
  else
    echo "resolved archive app is not Developer ID signed; update the Release target signing certificate in Xcode to Developer ID" >&2
  fi
  exit 1
}

json_get() {
  local json_file="$1"
  local expression="$2"

  /usr/bin/python3 - "$json_file" "$expression" <<'PY'
import json
import sys

json_file = sys.argv[1]
expression = sys.argv[2]

with open(json_file, encoding="utf-8") as handle:
    data = json.load(handle)

value = data
for part in expression.split("."):
    if not part:
        continue
    if isinstance(value, list):
        value = value[int(part)]
    else:
        value = value[part]

if isinstance(value, (dict, list)):
    print(json.dumps(value))
elif value is None:
    print("")
else:
    print(value)
PY
}

delete_existing_asset() {
  local release_json="$1"
  local asset_name="$2"
  local asset_ids

  asset_ids="$(/usr/bin/python3 - "$release_json" "$asset_name" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    release = json.load(handle)

asset_name = sys.argv[2]
for asset in release.get("assets", []):
    if asset.get("name") == asset_name:
        print(asset["id"])
PY
)"

  if [[ -z "$asset_ids" ]]; then
    return
  fi

  while IFS= read -r asset_id; do
    [[ -z "$asset_id" ]] && continue
    log "Deleting existing release asset $asset_name ($asset_id)"
    curl --fail --silent --show-error \
      -X DELETE \
      -H "Authorization: Bearer $GITHUB_RELEASE_TOKEN" \
      -H "Accept: application/vnd.github+json" \
      "https://api.github.com/repos/$GITHUB_RELEASE_REPO/releases/assets/$asset_id" \
      >/dev/null
  done <<< "$asset_ids"
}

upload_asset() {
  local release_json="$1"
  local asset_path="$2"
  local content_type="$3"
  local upload_url asset_name encoded_name

  asset_name="$(basename "$asset_path")"
  upload_url="$(json_get "$release_json" "upload_url")"
  upload_url="${upload_url%%\{*}"
  encoded_name="${asset_name//+/%2B}"

  log "Uploading $asset_name to GitHub Release"
  curl --fail --silent --show-error \
    -X POST \
    -H "Authorization: Bearer $GITHUB_RELEASE_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: $content_type" \
    --data-binary "@$asset_path" \
    "$upload_url?name=$encoded_name" \
    >/dev/null
}

resolve_release() {
  local tag_name="$1"
  local version="$2"
  local response_file="$3"
  local status_code payload

  status_code="$(curl --silent --show-error \
    -o "$response_file" \
    -w '%{http_code}' \
    -H "Authorization: Bearer $GITHUB_RELEASE_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$GITHUB_RELEASE_REPO/releases/tags/$tag_name")"

  if [[ "$status_code" == "200" ]]; then
    return
  fi

  if [[ "$status_code" != "404" ]]; then
    echo "failed to resolve GitHub release for tag $tag_name (HTTP $status_code)" >&2
    cat "$response_file" >&2
    exit 1
  fi

  log "Creating GitHub Release $tag_name"
  payload="$(/usr/bin/python3 - "$tag_name" "$version" "$CI_COMMIT" <<'PY'
import json
import sys

tag_name, version, commit = sys.argv[1:4]
print(json.dumps({
    "tag_name": tag_name,
    "name": f"Grabber v{version}",
    "target_commitish": commit,
    "generate_release_notes": True,
}))
PY
)"

  status_code="$(curl --silent --show-error \
    -o "$response_file" \
    -w '%{http_code}' \
    -X POST \
    -H "Authorization: Bearer $GITHUB_RELEASE_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -H "Content-Type: application/json" \
    -d "$payload" \
    "https://api.github.com/repos/$GITHUB_RELEASE_REPO/releases")"

  if [[ "$status_code" != "201" ]]; then
    echo "failed to create GitHub release for tag $tag_name (HTTP $status_code)" >&2
    cat "$response_file" >&2
    exit 1
  fi
}

publish_github_release() {
  local version="$1"
  local output_dir="$2"
  local tag_name response_file zip_path checksum_path

  require_command curl
  require_env GITHUB_RELEASE_TOKEN
  require_env GITHUB_RELEASE_REPO

  tag_name="v$version"
  zip_path="$output_dir/grabber-$version.zip"
  checksum_path="$zip_path.sha256"
  response_file="$output_dir/github-release.json"

  resolve_release "$tag_name" "$version" "$response_file"
  delete_existing_asset "$response_file" "$(basename "$zip_path")"
  delete_existing_asset "$response_file" "$(basename "$checksum_path")"

  resolve_release "$tag_name" "$version" "$response_file"
  upload_asset "$response_file" "$zip_path" "application/zip"
  upload_asset "$response_file" "$checksum_path" "text/plain"
}

update_homebrew_tap() {
  local version="$1"
  local output_dir="$2"
  local rendered_cask tap_repo_dir auth_url default_branch

  require_command git
  require_env HOMEBREW_TAP_GITHUB_TOKEN
  require_env HOMEBREW_TAP_REPO

  rendered_cask="$output_dir/grabber.rb"
  tap_repo_dir="$output_dir/homebrew-grabber"
  auth_url="https://x-access-token:${HOMEBREW_TAP_GITHUB_TOKEN}@github.com/${HOMEBREW_TAP_REPO}.git"

  if [[ ! -f "$rendered_cask" ]]; then
    echo "rendered cask not found: $rendered_cask" >&2
    exit 1
  fi

  log "Updating Homebrew tap $HOMEBREW_TAP_REPO"
  rm -rf "$tap_repo_dir"
  git clone "$auth_url" "$tap_repo_dir" >/dev/null
  cd "$tap_repo_dir"

  git config user.name "Xcode Cloud"
  git config user.email "xcode-cloud@users.noreply.github.com"

  default_branch="$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')"
  mkdir -p Casks
  cp "$rendered_cask" Casks/grabber.rb

  if git diff --quiet -- Casks/grabber.rb; then
    log "No Homebrew cask changes to push"
    return
  fi

  git add Casks/grabber.rb
  git commit -m "Update grabber cask to v$version" >/dev/null
  git push origin "HEAD:$default_branch" >/dev/null
}

main() {
  local publish_release version output_dir package_script app_path

  if [[ "${CI_XCODE_CLOUD:-}" != "TRUE" ]]; then
    log "Not running in Xcode Cloud; skipping"
    exit 0
  fi

  if [[ "${CI_PRODUCT_PLATFORM:-}" != "macOS" ]]; then
    log "Workflow platform is ${CI_PRODUCT_PLATFORM:-unknown}; skipping"
    exit 0
  fi

  if [[ "${CI_XCODEBUILD_ACTION:-}" != "archive" ]]; then
    log "xcodebuild action is ${CI_XCODEBUILD_ACTION:-unknown}; skipping"
    exit 0
  fi

  if [[ "${CI_XCODEBUILD_EXIT_CODE:-1}" != "0" ]]; then
    log "xcodebuild failed with exit code ${CI_XCODEBUILD_EXIT_CODE:-unknown}; skipping publish"
    exit 0
  fi

  publish_release="${PUBLISH_RELEASE:-}"
  if [[ -z "$publish_release" && -n "${CI_TAG:-}" ]]; then
    publish_release=1
  fi

  if ! bool_env "${publish_release:-0}"; then
    log "Release publishing is disabled; set PUBLISH_RELEASE=1 or run from a tag build"
    exit 0
  fi

  version="${RELEASE_VERSION:-${CI_TAG:-}}"
  version="${version#v}"
  if [[ -z "$version" ]]; then
    echo "could not determine release version; set RELEASE_VERSION or build from a v<version> tag" >&2
    exit 1
  fi

  app_path="$(resolve_app_path || true)"
  if [[ -z "$app_path" ]]; then
    echo "could not resolve an exported app bundle from CI_DEVELOPER_ID_SIGNED_APP_PATH or CI_ARCHIVE_PATH; confirm the workflow runs a macOS archive action and produces app artifacts" >&2
    exit 1
  fi

  validate_developer_id_signing "$app_path"

  package_script="${CI_PRIMARY_REPOSITORY_PATH}/scripts/package_release.sh"
  if [[ ! -x "$package_script" ]]; then
    echo "package script not found or not executable: $package_script" >&2
    exit 1
  fi

  output_dir="${CI_WORKSPACE_PATH}/release"
  export GITHUB_RELEASE_REPO="${GITHUB_RELEASE_REPO:-ihsur7/grabber}"
  export HOMEBREW_TAP_REPO="${HOMEBREW_TAP_REPO:-ihsur7/homebrew-grabber}"

  log "Packaging release artifacts for v$version"
  PREBUILT_APP_PATH="$app_path" \
    HOMEBREW_CASK_SOURCE_REPOSITORY="$GITHUB_RELEASE_REPO" \
    "$package_script" "$version" "$output_dir"

  publish_github_release "$version" "$output_dir"
  update_homebrew_tap "$version" "$output_dir"
}

main "$@"