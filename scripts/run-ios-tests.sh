#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
project="$root_dir/apps/apple/PixelForgeApp/PixelForgeApp.xcodeproj"
derived_data="$root_dir/build/ios-tests-derived"
device_id="${PIXEL_FORGE_SIMULATOR_ID:-}"

if [[ -z "$device_id" ]]; then
  device_id="$(xcrun simctl list devices available | sed -nE 's/^[[:space:]]+iPhone[^\(]*\(([0-9A-F-]{36})\).*/\1/p' | head -n 1)"
fi
if [[ -z "$device_id" ]]; then
  echo "ios tests: no available iPhone Simulator" >&2
  exit 1
fi

xcodebuild \
  -project "$project" \
  -scheme PixelForgeApp \
  -destination "platform=iOS Simulator,id=$device_id" \
  -derivedDataPath "$derived_data" \
  CODE_SIGNING_ALLOWED=NO \
  test \
  -quiet
