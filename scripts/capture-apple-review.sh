#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
app_dir="$root_dir/apps/apple/PixelForgeApp"
binary="$app_dir/.build/debug/PixelForgeApp"
input_path="${1:-}"

if [[ -z "$input_path" || ! -f "$input_path" ]]; then
  echo "usage: $0 /absolute/path/to/input.png-or-jpg" >&2
  exit 64
fi

swift build --package-path "$app_dir"

mkdir -p "$root_dir/designs/reviews"

for theme in dark light; do
  output="$root_dir/designs/reviews/pixel-forge-workbench--diagonal-pixel-border-icons-v2--$theme.png"
  "$binary" \
    --theme "$theme" \
    --open "$input_path" \
    --capture-review "$output"
  echo "captured ${output#$root_dir/}"
done
