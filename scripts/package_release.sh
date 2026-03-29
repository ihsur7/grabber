#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <version> [output-dir]" >&2
  exit 1
fi

version="$1"
output_dir="${2:-build/release}"
homebrew_cask_file="homebrew/grabber.rb"
derived_data_dir="$output_dir/DerivedData"
build_products_dir="$derived_data_dir/Build/Products/Release"
app_path="$build_products_dir/grabber.app"
zip_path="$output_dir/grabber-$version.zip"
checksum_path="$zip_path.sha256"

rm -rf "$output_dir"
mkdir -p "$output_dir"

xcodebuild \
  -project "grabber.xcodeproj" \
  -scheme "grabber" \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "$derived_data_dir" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

if [[ ! -d "$app_path" ]]; then
  echo "expected app bundle not found: $app_path" >&2
  exit 1
fi

ditto -c -k --sequesterRsrc --keepParent "$app_path" "$zip_path"
shasum -a 256 "$zip_path" | awk '{print $1 "  " $2}' > "$checksum_path"
checksum="$(cut -d' ' -f1 "$checksum_path")"

if [[ -f "$homebrew_cask_file" ]]; then
  perl -0pi -e "s/^  sha256 \".*\"$/  sha256 \"$checksum\"/m" "$homebrew_cask_file"
else
  echo "warning: $homebrew_cask_file not found, skipping cask checksum update" >&2
fi

echo "$zip_path"
echo "$checksum_path"
