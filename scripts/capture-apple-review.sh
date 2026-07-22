#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
project="$root_dir/apps/apple/PixelForgeApp/PixelForgeApp.xcodeproj"
derived_data="$root_dir/build/apple-review-derived"
bundle_id="com.kazuvin.pixelforge"
device_id="${PIXEL_FORGE_SIMULATOR_ID:-}"

if [[ -z "$device_id" ]]; then
  device_id="$(xcrun simctl list devices available | sed -nE 's/^[[:space:]]+iPhone[^\(]*\(([0-9A-F-]{36})\).*/\1/p' | head -n 1)"
fi
if [[ -z "$device_id" ]]; then
  echo "capture failed: no available iPhone Simulator" >&2
  exit 1
fi

xcodebuild \
  -project "$project" \
  -scheme PixelForgeApp \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build \
  -quiet

xcodebuild \
  -project "$project" \
  -scheme PixelForgeApp-Developer \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  build \
  -quiet

app_path="$derived_data/Build/Products/Debug-iphonesimulator/PixelForgeApp.app"
developer_app_path="$derived_data/Build/Products/Developer-iphonesimulator/PixelForgeApp.app"
if [[ ! -d "$app_path" ]]; then
  echo "capture failed: app bundle was not built" >&2
  exit 1
fi
if [[ ! -d "$developer_app_path" ]]; then
  echo "capture failed: developer app bundle was not built" >&2
  exit 1
fi

if ! xcrun simctl boot "$device_id" >/dev/null 2>&1; then
  true
fi
xcrun simctl bootstatus "$device_id" -b
if ! xcrun simctl uninstall "$device_id" "$bundle_id" >/dev/null 2>&1; then
  true
fi
xcrun simctl install "$device_id" "$app_path"
xcrun simctl status_bar "$device_id" override \
  --time 9:41 \
  --batteryState charged \
  --batteryLevel 100 \
  --wifiBars 3 \
  --cellularBars 4

mkdir -p "$root_dir/designs/reviews"

capture() {
  local screen="$1"
  local theme="$2"
  local output="$root_dir/designs/reviews/pixel-forge-$screen--$theme.png"
  local temporary_output="${output%.png}.$$.capturing.png"

  if ! xcrun simctl terminate "$device_id" "$bundle_id" >/dev/null 2>&1; then
    true
  fi
  xcrun simctl ui "$device_id" appearance "$theme"
  xcrun simctl launch "$device_id" "$bundle_id" \
    --review-screen "$screen" \
    --review-theme "$theme" \
    --review-language ja >/dev/null
  sleep 3
  xcrun simctl io "$device_id" screenshot "$temporary_output" >/dev/null
  mv "$temporary_output" "$output"
  echo "captured ${output#$root_dir/}"
}

for theme in dark light; do
  capture home "$theme"
  capture image-source-menu "$theme"
  capture delete-dialog "$theme"
  capture conversion-editing "$theme"
  capture palette-picker "$theme"
  capture recipe-preset-library "$theme"
  capture conversion-result "$theme"
  capture settings "$theme"
done

if ! xcrun simctl uninstall "$device_id" "$bundle_id" >/dev/null 2>&1; then
  true
fi
xcrun simctl install "$device_id" "$developer_app_path"
for theme in dark light; do
  capture settings-developer "$theme"
done

xcrun simctl status_bar "$device_id" clear
