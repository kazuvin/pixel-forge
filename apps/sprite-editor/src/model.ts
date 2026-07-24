import type {
  EditMode,
  ResizeAnchor,
  SizeDelta,
  SpriteManifest,
  SpritePart,
} from "./types";

export type FrameMetric = "x" | "y" | "width" | "height" | "zIndex";

const DEFAULT_POINT = { x: 0, y: 0 };
const DEFAULT_SIZE_DELTA = { width: 0, height: 0 };

export function normalizeManifest(manifest: SpriteManifest): SpriteManifest {
  const frameCount = manifest.animation.frames;
  return {
    ...manifest,
    schemaVersion: 2,
    parts: manifest.parts.map((part) => ({
      ...part,
      offsets: Array.from(
        { length: frameCount },
        (_, index) => part.offsets?.[index] ?? DEFAULT_POINT,
      ),
      sizeDeltas: Array.from(
        { length: frameCount },
        (_, index) => part.sizeDeltas?.[index] ?? DEFAULT_SIZE_DELTA,
      ),
      zIndexDeltas: Array.from(
        { length: frameCount },
        (_, index) => part.zIndexDeltas?.[index] ?? 0,
      ),
      resizeAnchor: part.resizeAnchor ?? "center",
    })),
  };
}

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

export function changeFrameSize(
  manifest: SpriteManifest,
  partId: string,
  frame: number,
  axis: keyof SizeDelta,
  value: number,
): SpriteManifest {
  return updatePart(manifest, partId, (part) => ({
    ...part,
    sizeDeltas: part.sizeDeltas.map((sizeDelta, index) =>
      index === frame ? { ...sizeDelta, [axis]: value } : sizeDelta,
    ),
  }));
}

export function changeFrameZIndexDelta(
  manifest: SpriteManifest,
  partId: string,
  frame: number,
  value: number,
): SpriteManifest {
  return updatePart(manifest, partId, (part) => ({
    ...part,
    zIndexDeltas: part.zIndexDeltas.map((zIndexDelta, index) =>
      index === frame ? value : zIndexDelta,
    ),
  }));
}

export function changeResizeAnchor(
  manifest: SpriteManifest,
  partId: string,
  resizeAnchor: ResizeAnchor,
): SpriteManifest {
  return updatePart(manifest, partId, (part) => ({
    ...part,
    resizeAnchor,
  }));
}

export function changeFrameMetric(
  manifest: SpriteManifest,
  partId: string,
  frame: number,
  metric: FrameMetric,
  value: number,
): SpriteManifest {
  switch (metric) {
    case "x":
    case "y":
      return changeFrameOffset(manifest, partId, frame, metric, value);
    case "width":
    case "height":
      return changeFrameSize(manifest, partId, frame, metric, value);
    case "zIndex":
      return changeFrameZIndexDelta(manifest, partId, frame, value);
  }
}

export function getFrameMetric(
  part: SpritePart,
  frame: number,
  metric: FrameMetric,
): number {
  switch (metric) {
    case "x":
    case "y":
      return part.offsets[frame]?.[metric] ?? 0;
    case "width":
    case "height":
      return part.sizeDeltas[frame]?.[metric] ?? 0;
    case "zIndex":
      return part.zIndexDeltas[frame] ?? 0;
  }
}

export function effectiveZIndex(part: SpritePart, frame: number): number {
  return part.zIndex + (part.zIndexDeltas[frame] ?? 0);
}

export function reorderPart(
  manifest: SpriteManifest,
  partId: string,
  direction: "forward" | "backward",
): SpriteManifest {
  const ordered = manifest.parts
    .map((part, manifestIndex) => ({ part, manifestIndex }))
    .sort(
      (left, right) =>
        left.part.zIndex - right.part.zIndex ||
        left.manifestIndex - right.manifestIndex,
    )
    .map(({ part }) => part);
  const currentIndex = ordered.findIndex((part) => part.id === partId);
  const targetIndex =
    currentIndex + (direction === "forward" ? 1 : -1);
  if (
    currentIndex < 0 ||
    targetIndex < 0 ||
    targetIndex >= ordered.length
  ) {
    return manifest;
  }
  [ordered[currentIndex], ordered[targetIndex]] = [
    ordered[targetIndex],
    ordered[currentIndex],
  ];
  const zIndexById = new Map(
    ordered.map((part, index) => [part.id, (index + 1) * 10]),
  );
  return {
    ...manifest,
    parts: manifest.parts.map((part) => ({
      ...part,
      zIndex: zIndexById.get(part.id) ?? part.zIndex,
    })),
  };
}
