import { normalizeManifest } from "./model";
import type {
  Point,
  ResizeAnchor,
  SizeDelta,
  SpriteManifest,
  SpritePart,
} from "./types";

type MotionRole = "head" | "body" | "arm" | "leg" | "equipment" | "other";

type MotionPattern = {
  x?: number[];
  y?: number[];
  width?: number[];
  height?: number[];
  anchor?: ResizeAnchor;
};

export type MotionPreset = {
  id: string;
  name: string;
  description: string;
  patterns: Record<MotionRole, MotionPattern>;
};

const zeros = [0, 0, 0, 0, 0, 0, 0, 0];

export const motionPresets: MotionPreset[] = [
  {
    id: "still",
    name: "静止",
    description: "変形を消して完全に止めます。",
    patterns: {
      head: {},
      body: {},
      arm: {},
      leg: { anchor: "bottom-center" },
      equipment: {},
      other: {},
    },
  },
  {
    id: "gentle-idle",
    name: "呼吸",
    description: "頭から胴へ伝わる標準的な待機モーション。",
    patterns: {
      head: { y: [0, 0, 1, 1, 2, 2, 1, 0] },
      body: { y: [0, 0, 1, 1, 1, 1, 0, 0] },
      arm: { y: [0, 0, 1, 1, 1, 1, 0, 0] },
      leg: {
        height: [0, 0, 0, -1, -1, -1, 0, 0],
        anchor: "bottom-center",
      },
      equipment: { y: [0, 0, 1, 1, 1, 1, 0, 0] },
      other: { y: [0, 0, 1, 1, 1, 1, 0, 0] },
    },
  },
  {
    id: "heavy-crouch",
    name: "重量級",
    description: "遅く深く沈み、脚を足裏固定で縮めます。",
    patterns: {
      head: { y: [0, 0, 0, 1, 2, 2, 1, 0] },
      body: { y: [0, 0, 0, 1, 1, 1, 0, 0] },
      arm: { y: [0, 0, 1, 1, 2, 1, 1, 0] },
      leg: {
        height: [0, 0, 0, -1, -2, -1, 0, 0],
        anchor: "bottom-center",
      },
      equipment: { y: [0, 0, 1, 1, 2, 1, 1, 0] },
      other: { y: [0, 0, 0, 1, 1, 1, 0, 0] },
    },
  },
  {
    id: "quick-bounce",
    name: "小刻み",
    description: "軽いキャラクター向けの速い上下運動。",
    patterns: {
      head: { y: [0, -1, 0, 1, 0, -1, 0, 0] },
      body: { y: [0, 0, 1, 1, 0, -1, 0, 0] },
      arm: { y: [0, -1, 0, 1, 1, 0, -1, 0] },
      leg: {
        height: [0, 0, -1, -1, 0, 0, -1, 0],
        anchor: "bottom-center",
      },
      equipment: { y: [0, -1, 0, 1, 1, 0, -1, 0] },
      other: { y: [0, 0, 1, 1, 0, -1, 0, 0] },
    },
  },
  {
    id: "hover",
    name: "浮遊",
    description: "全パーツを揃えて静かに浮かせます。",
    patterns: {
      head: { y: [0, -1, -1, -2, -2, -1, -1, 0] },
      body: { y: [0, -1, -1, -2, -2, -1, -1, 0] },
      arm: { y: [0, -1, -1, -2, -2, -1, -1, 0] },
      leg: {
        y: [0, -1, -1, -2, -2, -1, -1, 0],
        anchor: "bottom-center",
      },
      equipment: { y: [0, -1, -1, -2, -2, -1, -1, 0] },
      other: { y: [0, -1, -1, -2, -2, -1, -1, 0] },
    },
  },
];

export function applyMotionPreset(
  source: SpriteManifest,
  preset: MotionPreset,
): SpriteManifest {
  const manifest = normalizeManifest(source);
  return {
    ...manifest,
    parts: manifest.parts.map((part) => {
      const pattern = preset.patterns[roleForPart(part)];
      return {
        ...part,
        offsets: Array.from({ length: manifest.animation.frames }, (_, frame) => ({
          x: sample(pattern.x ?? zeros, frame, manifest.animation.frames),
          y: sample(pattern.y ?? zeros, frame, manifest.animation.frames),
        })) satisfies Point[],
        sizeDeltas: Array.from(
          { length: manifest.animation.frames },
          (_, frame) => ({
            width: sample(
              pattern.width ?? zeros,
              frame,
              manifest.animation.frames,
            ),
            height: sample(
              pattern.height ?? zeros,
              frame,
              manifest.animation.frames,
            ),
          }),
        ) satisfies SizeDelta[],
        resizeAnchor: pattern.anchor ?? part.resizeAnchor,
      };
    }),
  };
}

function roleForPart(part: SpritePart): MotionRole {
  const id = part.id.toLowerCase();
  if (id.includes("head") || id.includes("face")) {
    return "head";
  }
  if (
    id.includes("leg") ||
    id.includes("foot") ||
    id.includes("feet") ||
    id.includes("knee")
  ) {
    return "leg";
  }
  if (
    id.includes("arm") ||
    id.includes("hand") ||
    id.includes("claw") ||
    id.includes("wing")
  ) {
    return "arm";
  }
  if (
    id.includes("weapon") ||
    id.includes("shield") ||
    id.includes("equipment") ||
    id.includes("staff") ||
    id.includes("club") ||
    id.includes("sword")
  ) {
    return "equipment";
  }
  if (
    id.includes("body") ||
    id.includes("torso") ||
    id.includes("chest") ||
    id.includes("core")
  ) {
    return "body";
  }
  return "other";
}

function sample(pattern: number[], frame: number, frameCount: number): number {
  if (frameCount <= 1 || pattern.length <= 1) {
    return pattern[0] ?? 0;
  }
  const sourceIndex = Math.round(
    (frame * (pattern.length - 1)) / (frameCount - 1),
  );
  return pattern[sourceIndex] ?? 0;
}
