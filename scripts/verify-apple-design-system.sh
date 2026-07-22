#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd "$script_dir/.." && pwd)"
app_dir="$root_dir/apps/apple/PixelForgeApp/Sources/PixelForgeApp"
design_dir="$app_dir/Design"
screens_dir="$app_dir/Screens"
resources_dir="$app_dir/Resources"
project_spec="$root_dir/apps/apple/PixelForgeApp/project.yml"
review_screens=(home conversion-editing conversion-result settings)
review_themes=(dark light)

required_files=(
  "$design_dir/ForgeDesignTokens.swift"
  "$design_dir/ForgeTypography.swift"
  "$design_dir/ForgeComponents.swift"
  "$design_dir/ForgeIcons.swift"
  "$resources_dir/Fonts/DotGothic16-Regular.ttf"
  "$resources_dir/Fonts/OFL.txt"
  "$resources_dir/ja.lproj/Localizable.strings"
  "$resources_dir/en.lproj/Localizable.strings"
  "$project_spec"
  "$root_dir/apps/apple/PixelForgeApp/Supporting/Info.plist"
)

for required_file in "${required_files[@]}"; do
  if [[ ! -s "$required_file" ]]; then
    echo "design-system check: required file is missing or empty: ${required_file#$root_dir/}" >&2
    exit 1
  fi
done

if rg -n 'Image\(systemName:' "$design_dir" "$screens_dir"; then
  echo "design-system check: use ForgeIcon instead of SF Symbols" >&2
  exit 1
fi

if rg -n 'RoundedRectangle\(' "$design_dir" "$screens_dir"; then
  echo "design-system check: use ForgePixelChamferShape and ForgePixelBorder for pixel UI corners" >&2
  exit 1
fi

for screen in "${review_screens[@]}"; do
  for theme in "${review_themes[@]}"; do
    screenshot="designs/reviews/pixel-forge-$screen--$theme.png"
    if [[ ! -s "$root_dir/$screenshot" ]]; then
      echo "design-system check: required review screenshot is missing: $screenshot" >&2
      exit 1
    fi
    pixel_width="$(sips -g pixelWidth "$root_dir/$screenshot" | awk '/pixelWidth/ {print $2}')"
    pixel_height="$(sips -g pixelHeight "$root_dir/$screenshot" | awk '/pixelHeight/ {print $2}')"
    if (( pixel_width >= pixel_height )); then
      echo "design-system check: review screenshot must be portrait: $screenshot" >&2
      exit 1
    fi
  done
done

if ! rg -q 'TARGETED_DEVICE_FAMILY: "1"' "$project_spec"; then
  echo "design-system check: the app must target iPhone only" >&2
  exit 1
fi
if ! rg -q 'SUPPORTS_MACCATALYST: NO' "$project_spec"; then
  echo "design-system check: Mac Catalyst must stay disabled" >&2
  exit 1
fi
if rg -n 'UIInterfaceOrientationLandscape|platform:[[:space:]]*macOS|import AppKit' \
  "$project_spec" "$app_dir"; then
  echo "design-system check: the app must remain iPhone portrait only" >&2
  exit 1
fi

for localization in \
  "$resources_dir/ja.lproj/Localizable.strings" \
  "$resources_dir/en.lproj/Localizable.strings"; do
  plutil -lint "$localization" >/dev/null
done

temporary_dir="$(mktemp -d "${TMPDIR:-/tmp}/pixel-forge-design-check.XXXXXX")"
trap 'rm -rf "$temporary_dir"' EXIT

sed -nE 's/^"([^"]+)".*/\1/p' "$resources_dir/ja.lproj/Localizable.strings" | sort > "$temporary_dir/ja-keys"
sed -nE 's/^"([^"]+)".*/\1/p' "$resources_dir/en.lproj/Localizable.strings" | sort > "$temporary_dir/en-keys"
if ! diff -u "$temporary_dir/ja-keys" "$temporary_dir/en-keys"; then
  echo "design-system check: Japanese and English localization keys differ" >&2
  exit 1
fi

expected_font_sha="3ad9af88726d42b40f7f365f0dcac785af73cf20ea6f1d5b44e57cc21150b8f1"
actual_font_sha="$(shasum -a 256 "$resources_dir/Fonts/DotGothic16-Regular.ttf" | awk '{print $1}')"
if [[ "$actual_font_sha" != "$expected_font_sha" ]]; then
  echo "design-system check: bundled DotGothic16 font does not match the reviewed asset" >&2
  exit 1
fi

for screen in "$screens_dir"/*.swift; do
  if rg -n 'Color\(|\.(font|fontWeight|foregroundStyle|buttonStyle|clipShape)\(|\.(background|overlay)(\(|[[:space:]]*\{)' "$screen"; then
    echo "design-system check: screen styles must come from Design/ components: ${screen#$root_dir/}" >&2
    exit 1
  fi
  if rg -n '^[[:space:]]*(private[[:space:]]+)?struct[[:space:]].*(Button|Card|Panel|Header|Badge|Chip|Surface|Style)' "$screen"; then
    echo "design-system check: reusable UI primitives belong in Design/, not Screens/: ${screen#$root_dir/}" >&2
    exit 1
  fi
  if ! rg -q '\bForge[A-Z][A-Za-z]+' "$screen"; then
    echo "design-system check: screen must compose Forge design-system components: ${screen#$root_dir/}" >&2
    exit 1
  fi
done

for component in ForgeCanvas ForgeTopBar ForgeGeneratedCard ForgeLibraryEmpty ForgeSettingsButton; do
  if ! rg -q "\\b${component}\\b" "$screens_dir/WorkbenchView.swift"; then
    echo "design-system check: WorkbenchView must use shared component $component" >&2
    exit 1
  fi
done

for component in ForgeCanvas ForgeModalHeader ForgePreviewPane ForgePixelSurface ForgeButton; do
  if ! rg -q "\\b${component}\\b" "$screens_dir/ConversionModalView.swift"; then
    echo "design-system check: ConversionModalView must use shared component $component" >&2
    exit 1
  fi
done

if ! rg -q '\bForgeIcon\b' "$design_dir/ForgeComponents.swift"; then
  echo "design-system check: shared controls must use ForgeIcon" >&2
  exit 1
fi

if ! rg -q '\bForgePixelBorder\b' "$design_dir/ForgeComponents.swift"; then
  echo "design-system check: shared surfaces must use ForgePixelBorder" >&2
  exit 1
fi

if ! rg -q '\bForgeThemeCard\b' "$screens_dir/ThemeSettingsView.swift"; then
  echo "design-system check: ThemeSettingsView must use ForgeThemeCard" >&2
  exit 1
fi

if git -C "$root_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  base_ref="HEAD"
  current_branch="$(git -C "$root_dir" branch --show-current)"
  if [[ -n "${PIXEL_FORGE_BASE_REF:-}" ]]; then
    base_ref="$PIXEL_FORGE_BASE_REF"
  elif [[ "$current_branch" != "main" ]] && git -C "$root_dir" rev-parse --verify origin/main >/dev/null 2>&1; then
    base_ref="$(git -C "$root_dir" merge-base HEAD origin/main)"
  fi

  {
    git -C "$root_dir" diff --name-only "$base_ref"
    git -C "$root_dir" diff --name-only --cached "$base_ref"
    git -C "$root_dir" ls-files --others --exclude-standard
  } | sort -u > "$temporary_dir/changed-files"

  if rg -q '^apps/apple/PixelForgeApp/Sources/PixelForgeApp/(Design|Screens)/.*\.swift$' "$temporary_dir/changed-files"; then
    for screen in "${review_screens[@]}"; do
      for theme in "${review_themes[@]}"; do
        screenshot="designs/reviews/pixel-forge-$screen--$theme.png"
        if ! rg -Fxq "$screenshot" "$temporary_dir/changed-files"; then
          echo "design-system check: SwiftUI design changes require an updated $screenshot" >&2
          exit 1
        fi
      done
    done
  fi
fi

echo "apple design-system check passed"
