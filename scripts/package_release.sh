#!/usr/bin/env bash

set -euo pipefail

log() {
  echo "==> $*"
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

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <version> [output-dir]" >&2
  exit 1
fi

version="$1"
output_dir="${2:-build/release}"
homebrew_cask_template_file="homebrew/grabber.rb.template"
rendered_cask_file="$output_dir/grabber.rb"
cask_source_repository="${HOMEBREW_CASK_SOURCE_REPOSITORY:-ihsur7/grabber}"
derived_data_dir="$output_dir/DerivedData"
build_products_dir="$derived_data_dir/Build/Products/Release"
source_app_path="${PREBUILT_APP_PATH:-$build_products_dir/Grabber.app}"
staging_dir="$output_dir/staged"
app_path="$staging_dir/Grabber.app"
app_icon_fallback_file="grabber/Resources/Icon.icns"
zip_path="$output_dir/grabber-$version.zip"
checksum_path="$zip_path.sha256"
sign_release="${SIGN_RELEASE:-0}"
notarize_release="${NOTARIZE_RELEASE:-0}"
allow_app_icon_repair=1

if bool_env "$notarize_release" && ! bool_env "$sign_release"; then
  sign_release=1
fi

build_app() {
  if [[ -n "${PREBUILT_APP_PATH:-}" ]]; then
    log "Skipping build; using prebuilt app bundle at $source_app_path"
    allow_app_icon_repair=0
    return
  fi

  log "Building app bundle"

  xcodebuild \
    -project "grabber.xcodeproj" \
    -scheme "grabber" \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$derived_data_dir" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    MARKETING_VERSION="$version" \
    build
}

stage_app() {
  if [[ ! -d "$source_app_path" ]]; then
    echo "expected app bundle not found: $source_app_path" >&2
    exit 1
  fi

  log "Staging app bundle"
  rm -rf "$staging_dir"
  mkdir -p "$staging_dir"
  ditto "$source_app_path" "$app_path"
}

ensure_app_icon() {
  local info_plist icon_file icon_name icon_path

  info_plist="$app_path/Contents/Info.plist"
  icon_file="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$info_plist" 2>/dev/null || true)"
  icon_name="${icon_file:-Icon}"
  icon_name="${icon_name%.icns}"
  icon_path="$app_path/Contents/Resources/$icon_name.icns"

  if [[ -f "$icon_path" ]]; then
    log "Found bundled app icon at $icon_path"
    return
  fi

  if [[ "$allow_app_icon_repair" -ne 1 ]]; then
    echo "prebuilt app bundle is missing its icon at $icon_path" >&2
    exit 1
  fi

  if [[ ! -f "$app_icon_fallback_file" ]]; then
    echo "expected app icon not found and fallback file is missing: $app_icon_fallback_file" >&2
    exit 1
  fi

  log "App icon missing from built app; copying fallback ICNS from $app_icon_fallback_file"
  cp "$app_icon_fallback_file" "$icon_path"
}

sign_app() {
  if ! bool_env "$sign_release"; then
    log "Skipping code signing"
    return
  fi

  require_command codesign
  require_env DEVELOPER_ID_APPLICATION

  log "Signing app bundle with Developer ID"
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" \
    "$app_path"

  log "Verifying code signature"
  codesign --verify --deep --strict --verbose=2 "$app_path"
}

package_zip() {
  log "Packaging release zip"
  rm -f "$zip_path"
  ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
}

notarize_zip() {
  if ! bool_env "$notarize_release"; then
    log "Skipping notarization"
    return
  fi

  require_command xcrun
  require_env NOTARYTOOL_KEY_ID
  require_env NOTARYTOOL_ISSUER_ID
  require_env NOTARYTOOL_KEY_PATH

  log "Submitting release zip for notarization"
  xcrun notarytool submit "$zip_path" \
    --key "$NOTARYTOOL_KEY_PATH" \
    --key-id "$NOTARYTOOL_KEY_ID" \
    --issuer "$NOTARYTOOL_ISSUER_ID" \
    --wait

  log "Stapling notarization ticket"
  xcrun stapler staple "$app_path"
  xcrun stapler validate "$app_path"

  package_zip
}

write_checksum() {
  log "Writing checksum"
  shasum -a 256 "$zip_path" | awk '{print $1 "  " $2}' > "$checksum_path"
}

update_cask_checksum() {
  local checksum

  checksum="$(cut -d' ' -f1 "$checksum_path")"

  if [[ -f "$homebrew_cask_template_file" ]]; then
    log "Rendering Homebrew cask"
    perl -0pe \
      "s/REPLACE_WITH_RELEASE_VERSION/$version/g; s/REPLACE_WITH_RELEASE_SHA256/$checksum/g; s|OWNER/REPO|$cask_source_repository|g" \
      "$homebrew_cask_template_file" > "$rendered_cask_file"
  else
    echo "warning: $homebrew_cask_template_file not found, skipping cask rendering" >&2
  fi
}

rm -rf "$output_dir"
mkdir -p "$output_dir"

build_app
stage_app
ensure_app_icon
sign_app
package_zip
notarize_zip
write_checksum
update_cask_checksum

echo "$zip_path"
echo "$checksum_path"
if [[ -f "$rendered_cask_file" ]]; then
  echo "$rendered_cask_file"
fi
