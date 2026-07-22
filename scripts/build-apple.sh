#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
build_dir="$root_dir/build/apple"
bindings_dir="$build_dir/bindings"
headers_dir="$build_dir/headers"
library_dir="$build_dir/library"
artifact_path="$root_dir/packages/PixelCoreKit/Artifacts/PixelForgeCoreFFI.xcframework"
generated_swift="$root_dir/packages/PixelCoreKit/Sources/PixelCoreKit/Generated/PixelForgeCore.swift"

mkdir -p "$bindings_dir" "$headers_dir" "$library_dir" "$(dirname "$artifact_path")" "$(dirname "$generated_swift")"

cargo build --manifest-path "$root_dir/Cargo.toml" --release -p pixel-ffi
cargo run --manifest-path "$root_dir/Cargo.toml" -p pixel-uniffi-bindgen -- \
  generate \
  --library "$root_dir/target/release/libpixel_ffi.dylib" \
  --language swift \
  --out-dir "$bindings_dir"

swift_source="$(find "$bindings_dir" -maxdepth 1 -name '*.swift' -print -quit)"
ffi_header="$(find "$bindings_dir" -maxdepth 1 -name '*.h' -print -quit)"
module_map="$(find "$bindings_dir" -maxdepth 1 -name '*.modulemap' -print -quit)"

if [[ -z "$swift_source" || -z "$ffi_header" || -z "$module_map" ]]; then
  echo "UniFFI did not generate the expected Swift, header, and modulemap files" >&2
  exit 1
fi

cp "$swift_source" "$generated_swift"
cp "$ffi_header" "$headers_dir/$(basename "$ffi_header")"
cp "$module_map" "$headers_dir/module.modulemap"
cp "$root_dir/target/release/libpixel_ffi.a" "$library_dir/libPixelForgeCoreFFI.a"

expected_artifact="$root_dir/packages/PixelCoreKit/Artifacts/PixelForgeCoreFFI.xcframework"
if [[ "$artifact_path" != "$expected_artifact" ]]; then
  echo "Refusing to replace an unexpected artifact path: $artifact_path" >&2
  exit 1
fi
rm -rf "$artifact_path"

xcodebuild -create-xcframework \
  -library "$library_dir/libPixelForgeCoreFFI.a" \
  -headers "$headers_dir" \
  -output "$artifact_path"

echo "Generated $artifact_path"

