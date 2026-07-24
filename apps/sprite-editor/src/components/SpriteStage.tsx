import {
  useRef,
  useState,
  type CSSProperties,
  type SyntheticEvent,
  type PointerEvent,
} from "react";

import { partImageUrl } from "../api";
import { effectiveZIndex } from "../model";
import type { ResizeAnchor, SpriteManifest, SpritePart } from "../types";

type SpriteStageProps = {
  manifest: SpriteManifest;
  frame: number;
  revision: string;
  selectedPartId: string;
  zoom: number;
  referenceUrl: string | null;
  referenceOpacity: number;
  onSelectPart: (partId: string) => void;
  onMovePart: (deltaX: number, deltaY: number) => void;
};

type DragState = {
  pointerId: number;
  startX: number;
  startY: number;
  movedX: number;
  movedY: number;
};

type PartBounds = {
  left: number;
  top: number;
  width: number;
  height: number;
};

type PartLayout = PartBounds & {
  imageLeft: number;
  imageTop: number;
  imageWidth: number;
  imageHeight: number;
  zIndex: number;
};

export function SpriteStage({
  manifest,
  frame,
  revision,
  selectedPartId,
  zoom,
  referenceUrl,
  referenceOpacity,
  onSelectPart,
  onMovePart,
}: SpriteStageProps) {
  const dragState = useRef<DragState | null>(null);
  const [partBounds, setPartBounds] = useState<Record<string, PartBounds>>({});
  const sortedParts = [...manifest.parts].sort(
    (left, right) =>
      effectiveZIndex(left, frame) - effectiveZIndex(right, frame),
  );
  const selectedPart = manifest.parts.find(
    (part) => part.id === selectedPartId,
  );

  const startDrag = (
    event: PointerEvent<HTMLButtonElement>,
    partId: string,
  ) => {
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    onSelectPart(partId);
    dragState.current = {
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      movedX: 0,
      movedY: 0,
    };
  };

  const continueDrag = (event: PointerEvent<HTMLButtonElement>) => {
    const drag = dragState.current;
    if (!drag || drag.pointerId !== event.pointerId) {
      return;
    }
    const nextX = Math.round((event.clientX - drag.startX) / zoom);
    const nextY = Math.round((event.clientY - drag.startY) / zoom);
    const deltaX = nextX - drag.movedX;
    const deltaY = nextY - drag.movedY;
    if (deltaX !== 0 || deltaY !== 0) {
      onMovePart(deltaX, deltaY);
      drag.movedX = nextX;
      drag.movedY = nextY;
    }
  };

  const stopDrag = (event: PointerEvent<HTMLButtonElement>) => {
    if (dragState.current?.pointerId === event.pointerId) {
      dragState.current = null;
    }
  };

  const measureOpaqueBounds = (
    partId: string,
    event: SyntheticEvent<HTMLImageElement>,
  ) => {
    if (partBounds[partId]) {
      return;
    }
    const image = event.currentTarget;
    const canvas = document.createElement("canvas");
    canvas.width = image.naturalWidth;
    canvas.height = image.naturalHeight;
    const context = canvas.getContext("2d", { willReadFrequently: true });
    if (!context) {
      return;
    }
    context.drawImage(image, 0, 0);
    const { data } = context.getImageData(0, 0, canvas.width, canvas.height);
    let left = canvas.width;
    let top = canvas.height;
    let right = -1;
    let bottom = -1;
    for (let y = 0; y < canvas.height; y += 1) {
      for (let x = 0; x < canvas.width; x += 1) {
        if (data[(y * canvas.width + x) * 4 + 3] === 0) {
          continue;
        }
        left = Math.min(left, x);
        top = Math.min(top, y);
        right = Math.max(right, x);
        bottom = Math.max(bottom, y);
      }
    }
    if (right < left || bottom < top) {
      return;
    }
    setPartBounds((current) => ({
      ...current,
      [partId]: {
        left,
        top,
        width: right - left + 1,
        height: bottom - top + 1,
      },
    }));
  };

  const offset = selectedPart?.offsets[frame] ?? { x: 0, y: 0 };
  const anchorX = selectedPart ? selectedPart.position.x + offset.x : 0;
  const anchorY = selectedPart ? selectedPart.position.y + offset.y : 0;

  return (
    <div className="stage-shell">
      <div className="axis axis-x" aria-hidden="true">
        {Array.from({ length: 9 }, (_, index) => (
          <span key={index}>{index * 8}</span>
        ))}
      </div>
      <div className="axis axis-y" aria-hidden="true">
        {Array.from({ length: 9 }, (_, index) => (
          <span key={index}>{index * 8}</span>
        ))}
      </div>
      <div
        className="sprite-stage"
        data-testid="sprite-stage"
        style={{
          width: manifest.canvas.width * zoom,
          height: manifest.canvas.height * zoom,
          "--pixel-zoom": zoom,
        } as CSSProperties & Record<"--pixel-zoom", number>}
      >
        {referenceUrl ? (
          <img
            className="reference-overlay"
            src={referenceUrl}
            alt=""
            style={{ opacity: referenceOpacity }}
          />
        ) : null}
        <div className="ground-guide" aria-hidden="true" />
        {sortedParts.map((part) => {
          const selected = part.id === selectedPartId;
          const bounds = partBounds[part.id] ?? {
            left: 0,
            top: 0,
            width: manifest.grid.logicalCellWidth,
            height: manifest.grid.logicalCellHeight,
          };
          const layout = computePartLayout(
            part,
            frame,
            bounds,
            manifest.grid.logicalCellWidth,
            manifest.grid.logicalCellHeight,
          );
          return (
            <button
              className={`stage-part${selected ? " is-selected" : ""}`}
              data-part-id={part.id}
              key={part.id}
              type="button"
              aria-label={`${part.id}を選択して移動`}
              style={{
                left: layout.left * zoom,
                top: layout.top * zoom,
                width: layout.width * zoom,
                height: layout.height * zoom,
                zIndex: layout.zIndex,
              }}
              onPointerDown={(event) => startDrag(event, part.id)}
              onPointerMove={continueDrag}
              onPointerUp={stopDrag}
              onPointerCancel={stopDrag}
            >
              <img
                src={partImageUrl(part.id, revision)}
                alt=""
                draggable={false}
                onLoad={(event) => measureOpaqueBounds(part.id, event)}
                style={{
                  left: layout.imageLeft * zoom,
                  top: layout.imageTop * zoom,
                  width: layout.imageWidth * zoom,
                  height: layout.imageHeight * zoom,
                }}
              />
            </button>
          );
        })}
        {selectedPart ? (
          <div
            className="anchor-marker"
            aria-label={`接続点 ${anchorX}, ${anchorY}`}
            style={{
              left: anchorX * zoom,
              top: anchorY * zoom,
              zIndex: 1000,
            }}
          >
            <span />
          </div>
        ) : null}
      </div>
    </div>
  );
}

type MiniFrameProps = {
  manifest: SpriteManifest;
  frame: number;
  revision: string;
};

export function MiniFrame({ manifest, frame, revision }: MiniFrameProps) {
  const [partBounds, setPartBounds] = useState<Record<string, PartBounds>>({});
  const parts = [...manifest.parts].sort(
    (left, right) =>
      effectiveZIndex(left, frame) - effectiveZIndex(right, frame),
  );
  const measureOpaqueBounds = (
    partId: string,
    event: SyntheticEvent<HTMLImageElement>,
  ) => {
    if (partBounds[partId]) {
      return;
    }
    const bounds = readOpaqueBounds(event.currentTarget);
    if (bounds) {
      setPartBounds((current) => ({ ...current, [partId]: bounds }));
    }
  };
  return (
    <div
      className="mini-frame"
      style={{
        width: manifest.canvas.width,
        height: manifest.canvas.height,
      }}
      aria-hidden="true"
    >
      {parts.map((part) => {
        const bounds = partBounds[part.id] ?? {
          left: 0,
          top: 0,
          width: manifest.grid.logicalCellWidth,
          height: manifest.grid.logicalCellHeight,
        };
        const layout = computePartLayout(
          part,
          frame,
          bounds,
          manifest.grid.logicalCellWidth,
          manifest.grid.logicalCellHeight,
        );
        return (
          <span
            key={part.id}
            style={{
              left: layout.left,
              top: layout.top,
              width: layout.width,
              height: layout.height,
              zIndex: layout.zIndex,
            }}
          >
            <img
              src={partImageUrl(part.id, revision)}
              alt=""
              onLoad={(event) => measureOpaqueBounds(part.id, event)}
              style={{
                left: layout.imageLeft,
                top: layout.imageTop,
                width: layout.imageWidth,
                height: layout.imageHeight,
              }}
            />
          </span>
        );
      })}
    </div>
  );
}

function readOpaqueBounds(image: HTMLImageElement): PartBounds | null {
  const canvas = document.createElement("canvas");
  canvas.width = image.naturalWidth;
  canvas.height = image.naturalHeight;
  const context = canvas.getContext("2d", { willReadFrequently: true });
  if (!context) {
    return null;
  }
  context.drawImage(image, 0, 0);
  const { data } = context.getImageData(0, 0, canvas.width, canvas.height);
  let left = canvas.width;
  let top = canvas.height;
  let right = -1;
  let bottom = -1;
  for (let y = 0; y < canvas.height; y += 1) {
    for (let x = 0; x < canvas.width; x += 1) {
      if (data[(y * canvas.width + x) * 4 + 3] === 0) {
        continue;
      }
      left = Math.min(left, x);
      top = Math.min(top, y);
      right = Math.max(right, x);
      bottom = Math.max(bottom, y);
    }
  }
  return right < left || bottom < top
    ? null
    : {
        left,
        top,
        width: right - left + 1,
        height: bottom - top + 1,
      };
}

function computePartLayout(
  part: SpritePart,
  frame: number,
  bounds: PartBounds,
  cellWidth: number,
  cellHeight: number,
): PartLayout {
  const offset = part.offsets[frame] ?? { x: 0, y: 0 };
  const sizeDelta = part.sizeDeltas[frame] ?? { width: 0, height: 0 };
  const width = Math.max(1, bounds.width + sizeDelta.width);
  const height = Math.max(1, bounds.height + sizeDelta.height);
  const sourcePivot = pivotOffsets(
    bounds.width,
    bounds.height,
    part.resizeAnchor,
  );
  const targetPivot = pivotOffsets(width, height, part.resizeAnchor);
  const left =
    part.position.x -
    part.anchor.x +
    offset.x +
    bounds.left +
    sourcePivot.x -
    targetPivot.x;
  const top =
    part.position.y -
    part.anchor.y +
    offset.y +
    bounds.top +
    sourcePivot.y -
    targetPivot.y;
  const scaleX = width / bounds.width;
  const scaleY = height / bounds.height;
  return {
    left,
    top,
    width,
    height,
    imageLeft: -bounds.left * scaleX,
    imageTop: -bounds.top * scaleY,
    imageWidth: cellWidth * scaleX,
    imageHeight: cellHeight * scaleY,
    zIndex: effectiveZIndex(part, frame),
  };
}

function pivotOffsets(
  width: number,
  height: number,
  anchor: ResizeAnchor,
): Point {
  const x = anchor.includes("left")
    ? 0
    : anchor.includes("right")
      ? width
      : Math.floor(width / 2);
  const y = anchor.includes("top")
    ? 0
    : anchor.includes("bottom")
      ? height
      : Math.floor(height / 2);
  return { x, y };
}

type Point = {
  x: number;
  y: number;
};
