import type { EditMode, SpriteManifest, SpritePart } from "./types";

export function updatePart(
  manifest: SpriteManifest,
  partId: string,
  updater: (part: SpritePart) => SpritePart,
): SpriteManifest {
  return {
    ...manifest,
    parts: manifest.parts.map((part) =>
      part.id === partId ? updater(part) : part,
    ),
  };
}

export function movePart(
  manifest: SpriteManifest,
  partId: string,
  editMode: EditMode,
  frame: number,
  deltaX: number,
  deltaY: number,
): SpriteManifest {
  return updatePart(manifest, partId, (part) => {
    if (editMode === "position") {
      return {
        ...part,
        position: {
          x: part.position.x + deltaX,
          y: part.position.y + deltaY,
        },
      };
    }

    const offsets = part.offsets.map((offset, index) =>
      index === frame
        ? { x: offset.x + deltaX, y: offset.y + deltaY }
        : offset,
    );
    return { ...part, offsets };
  });
}

export function changePartNumber(
  manifest: SpriteManifest,
  partId: string,
  field: "positionX" | "positionY" | "anchorX" | "anchorY" | "zIndex",
  value: number,
): SpriteManifest {
  return updatePart(manifest, partId, (part) => {
    switch (field) {
      case "positionX":
        return { ...part, position: { ...part.position, x: value } };
      case "positionY":
        return { ...part, position: { ...part.position, y: value } };
      case "anchorX":
        return { ...part, anchor: { ...part.anchor, x: value } };
      case "anchorY":
        return { ...part, anchor: { ...part.anchor, y: value } };
      case "zIndex":
        return { ...part, zIndex: value };
    }
  });
}

export function changeFrameOffset(
  manifest: SpriteManifest,
  partId: string,
  frame: number,
  axis: "x" | "y",
  value: number,
): SpriteManifest {
  return updatePart(manifest, partId, (part) => ({
    ...part,
    offsets: part.offsets.map((offset, index) =>
      index === frame ? { ...offset, [axis]: value } : offset,
    ),
  }));
}
