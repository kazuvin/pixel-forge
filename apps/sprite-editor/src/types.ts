export type Point = {
  x: number;
  y: number;
};

export type SizeDelta = {
  width: number;
  height: number;
};

export type ResizeAnchor =
  | "top-left"
  | "top-center"
  | "top-right"
  | "center-left"
  | "center"
  | "center-right"
  | "bottom-left"
  | "bottom-center"
  | "bottom-right";

export type SpritePart = {
  id: string;
  cell: {
    column: number;
    row: number;
  };
  anchor: Point;
  position: Point;
  zIndex: number;
  offsets: Point[];
  sizeDeltas: SizeDelta[];
  zIndexDeltas: number[];
  resizeAnchor: ResizeAnchor;
};

export type SpriteManifest = {
  schemaVersion: number;
  id: string;
  generation: {
    description: string;
    style: string;
    view: string;
    palette: string;
    chromaKey: string;
    avoid: string[];
  };
  grid: {
    columns: number;
    rows: number;
    logicalCellWidth: number;
    logicalCellHeight: number;
  };
  canvas: {
    width: number;
    height: number;
  };
  render: {
    colorCount: number;
    dither: string;
    previewScale: number;
  };
  animation: {
    name: string;
    frames: number;
    fps: number;
  };
  parts: SpritePart[];
};

export type ProjectPaths = {
  manifest: string;
  source: string;
  output: string;
};

export type ProjectPayload = {
  manifest: SpriteManifest;
  paths: ProjectPaths;
  revision: string;
};

export type EditMode = "position" | "offset";
