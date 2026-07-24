---
name: generate-monster-sprite
description: Generate a separated monster parts sheet with Codex imagegen and compile it into deterministic 8-frame transparent sprite assets with Pixel Forge. Use when creating a new game monster from a text description, regenerating its rig parts, or adjusting part anchors, layer order, and idle motion from a `.sprite.json` manifest.
---

# Generate Monster Sprite

Create the source bitmap with the standard `imagegen` skill, then use the local Rust CLI for all pixelization, splitting, animation, and packing.

## Workflow

1. Read `docs/sprite-workflow.md`.
2. Create the requested output directory inside the workspace.
3. Copy `examples/sprites/moss-golem/moss-golem.sprite.json` into that directory and adapt:
   - `id` and `generation`
   - parts and grid cells
   - anchors, canvas positions, z-order, frame offsets, and optional frame resize
   - use `#FF00FF` for green subjects and `#00FF00` otherwise
4. Validate the manifest:

   ```bash
   cargo run -p pixel-cli -- sprite validate <manifest>
   ```

5. Render the exact image-generation prompt:

   ```bash
   cargo run -p pixel-cli -- sprite prompt <manifest> --output <prompt.md>
   ```

6. Use the standard `imagegen` skill in built-in generation mode with the complete generated prompt. Do not replace it with an ad hoc image API or embed model calls in the Rust CLI.
7. Copy the selected square source into the project as `<id>.parts-chroma.png`.
8. Remove the flat background with the helper required by the `imagegen` skill:

   ```bash
   python3 "${CODEX_HOME:-$HOME/.codex}/skills/.system/imagegen/scripts/remove_chroma_key.py" \
     --input <id>.parts-chroma.png \
     --out <id>.parts.png \
     --auto-key border \
     --soft-matte \
     --transparent-threshold 12 \
     --opaque-threshold 220 \
     --despill
   ```

9. Build the assets:

   ```bash
   cargo run -p pixel-cli -- sprite build <manifest> \
     --source <id>.parts.png \
     --output <output-dir>
   ```

10. Inspect the logical sheet and enlarged preview. Keep feet grounded. Fix assembly by editing `anchor`, `position`, `zIndex`, `offsets`, `sizeDeltas`, `resizeAnchor`, or `zIndexDeltas` and rebuilding before regenerating the source.
11. Regenerate with one targeted prompt change only when a cell is missing, clipped, inconsistent, or contains the wrong part.

## Acceptance

- Every configured cell contains exactly one complete isolated part.
- Unlisted cells and borders are transparent after key removal.
- `sprite build` reports no empty parts.
- The output contains the logical sheet, scaled preview, frame metadata, recipe, and individual part PNGs.
- Frame 8 returns to frame 1 placement for a clean loop.
- Resize uses integer width/height deltas, an explicit fixed anchor, and nearest-neighbor only; no rotation, free scaling, IK, or provider-specific data enters the manifest or Rust core.
