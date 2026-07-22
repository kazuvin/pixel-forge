#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
smoke_dir="$root_dir/build/ci-smoke"

cd "$root_dir"

"$root_dir/scripts/verify-apple-design-system.sh"

cargo fmt --all --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace

mkdir -p "$smoke_dir"
cargo run -p pixel-cli -- \
  "$root_dir/fixtures/source-gradient.ppm" \
  --output "$smoke_dir/output.png" \
  --width 16 \
  --height 16 \
  --colors 6 \
  --dither bayer4x4 \
  --scale 4

"$root_dir/scripts/build-apple.sh"
swift test --package-path "$root_dir/packages/PixelCoreKit"
swift build --package-path "$root_dir/apps/apple/PixelForgeApp"

echo "ci-local passed"
