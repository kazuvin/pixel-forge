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
  convert \
  "$root_dir/fixtures/source-gradient.ppm" \
  --output "$smoke_dir/output.png" \
  --width 16 \
  --height 16 \
  --colors 6 \
  --dither bayer4x4 \
  --scale 4

cargo run -p pixel-cli -- sprite validate \
  "$root_dir/examples/sprites/moss-golem/moss-golem.sprite.json"
cargo run -p pixel-cli -- sprite prompt \
  "$root_dir/examples/sprites/moss-golem/moss-golem.sprite.json" \
  --output "$smoke_dir/moss-golem-imagegen-prompt.md"

"$root_dir/scripts/build-apple.sh"
swift test --package-path "$root_dir/packages/PixelCoreKit"
"$root_dir/scripts/run-ios-tests.sh"

corepack pnpm --filter @pixel-forge/web test
corepack pnpm --filter @pixel-forge/web check
corepack pnpm --filter @pixel-forge/web build
corepack pnpm --filter @pixel-forge/web deploy:dry-run
corepack pnpm --filter @pixel-forge/sprite-editor test
corepack pnpm --filter @pixel-forge/sprite-editor check
corepack pnpm --filter @pixel-forge/sprite-editor build

echo "ci-local passed"
