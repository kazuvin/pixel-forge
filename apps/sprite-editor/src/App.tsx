import {
  useCallback,
  useEffect,
  useMemo,
  useState,
  type ChangeEvent,
  type ReactNode,
} from "react";

import { loadProject, partImageUrl, saveProject } from "./api";
import { MiniFrame, SpriteStage } from "./components/SpriteStage";
import {
  changeFrameOffset,
  changePartNumber,
  movePart,
  updatePart,
} from "./model";
import type {
  EditMode,
  ProjectPaths,
  SpriteManifest,
  SpritePart,
} from "./types";

type SaveState = "loading" | "saved" | "dirty" | "building" | "error";

const moveLabels: Record<EditMode, string> = {
  position: "基準位置",
  offset: "このフレーム",
};

export function App() {
  const [manifest, setManifest] = useState<SpriteManifest | null>(null);
  const [paths, setPaths] = useState<ProjectPaths | null>(null);
  const [revision, setRevision] = useState("initial");
  const [selectedPartId, setSelectedPartId] = useState("");
  const [frame, setFrame] = useState(0);
  const [editMode, setEditMode] = useState<EditMode>("position");
  const [zoom, setZoom] = useState(8);
  const [playing, setPlaying] = useState(false);
  const [saveState, setSaveState] = useState<SaveState>("loading");
  const [message, setMessage] = useState("プロジェクトを読み込んでいます");
  const [referenceUrl, setReferenceUrl] = useState<string | null>(null);
  const [referenceOpacity, setReferenceOpacity] = useState(0.42);

  useEffect(() => {
    let active = true;
    loadProject()
      .then((project) => {
        if (!active) {
          return;
        }
        setManifest(project.manifest);
        setPaths(project.paths);
        setRevision(project.revision);
        setSelectedPartId(project.manifest.parts[0]?.id ?? "");
        setSaveState("saved");
        setMessage("CLIの出力と同期しました");
      })
      .catch((error: unknown) => {
        if (!active) {
          return;
        }
        setSaveState("error");
        setMessage(error instanceof Error ? error.message : String(error));
      });
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (!manifest || !playing) {
      return;
    }
    const interval = window.setInterval(() => {
      setFrame(
        (current) => (current + 1) % Math.max(manifest.animation.frames, 1),
      );
    }, 1000 / manifest.animation.fps);
    return () => window.clearInterval(interval);
  }, [manifest, playing]);

  const selectedPart = useMemo(
    () => manifest?.parts.find((part) => part.id === selectedPartId) ?? null,
    [manifest, selectedPartId],
  );

  const changeManifest = useCallback(
    (updater: (current: SpriteManifest) => SpriteManifest) => {
      setManifest((current) => (current ? updater(current) : current));
      setSaveState("dirty");
      setMessage("未保存の調整があります");
    },
    [],
  );

  const moveSelectedPart = useCallback(
    (deltaX: number, deltaY: number) => {
      if (!selectedPartId) {
        return;
      }
      changeManifest((current) =>
        movePart(
          current,
          selectedPartId,
          editMode,
          frame,
          deltaX,
          deltaY,
        ),
      );
    },
    [changeManifest, editMode, frame, selectedPartId],
  );

  const saveAndBuild = useCallback(async () => {
    if (!manifest || saveState === "building") {
      return;
    }
    setSaveState("building");
    setMessage("manifestを検証してSprite Assetを再ビルドしています");
    try {
      const result = await saveProject(manifest);
      setRevision(result.revision);
      setSaveState("saved");
      setMessage(result.log || "保存と再ビルドが完了しました");
    } catch (error) {
      setSaveState("error");
      setMessage(error instanceof Error ? error.message : String(error));
    }
  }, [manifest, saveState]);

  useEffect(() => {
    const handleKeyboard = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (
        target?.matches(
          "input, textarea, select, [contenteditable='true']",
        )
      ) {
        return;
      }
      if (target?.matches("button") && event.key === " ") {
        return;
      }
      const step = event.shiftKey ? 4 : 1;
      const movement: Record<string, [number, number]> = {
        ArrowLeft: [-step, 0],
        ArrowRight: [step, 0],
        ArrowUp: [0, -step],
        ArrowDown: [0, step],
      };
      if (movement[event.key]) {
        event.preventDefault();
        moveSelectedPart(...movement[event.key]);
      } else if (event.key === " ") {
        event.preventDefault();
        setPlaying((current) => !current);
      } else if (
        event.key.toLowerCase() === "s" &&
        (event.metaKey || event.ctrlKey)
      ) {
        event.preventDefault();
        void saveAndBuild();
      }
    };
    window.addEventListener("keydown", handleKeyboard);
    return () => window.removeEventListener("keydown", handleKeyboard);
  }, [moveSelectedPart, saveAndBuild]);

  const exportManifest = () => {
    if (!manifest) {
      return;
    }
    const blob = new Blob([`${JSON.stringify(manifest, null, 2)}\n`], {
      type: "application/json",
    });
    const downloadUrl = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = downloadUrl;
    link.download = `${manifest.id}.sprite.json`;
    link.click();
    URL.revokeObjectURL(downloadUrl);
  };

  const loadReference = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) {
      return;
    }
    setReferenceUrl((current) => {
      if (current) {
        URL.revokeObjectURL(current);
      }
      return URL.createObjectURL(file);
    });
  };

  if (!manifest || !paths) {
    return (
      <main className="loading-screen">
        <div className="loading-mark" aria-hidden="true" />
        <p>SPRITE RIG</p>
        <strong>{message}</strong>
      </main>
    );
  }

  const currentOffset = selectedPart?.offsets[frame] ?? { x: 0, y: 0 };
  const stateLabel = {
    loading: "読込中",
    saved: "保存済み",
    dirty: "未保存",
    building: "ビルド中",
    error: "要確認",
  }[saveState];

  return (
    <div className="application-shell">
      <header className="topbar">
        <div className="brand-lockup">
          <span className="brand-mark" aria-hidden="true">
            <i />
            <i />
            <i />
          </span>
          <div>
            <p>PIXEL FORGE / LOCAL TOOL</p>
            <h1>Sprite Rig</h1>
          </div>
        </div>
        <div className="project-heading">
          <p>編集中のモンスター</p>
          <strong>{manifest.id}</strong>
          <code>{paths.manifest}</code>
        </div>
        <div className="topbar-actions">
          <span className={`state-chip state-${saveState}`}>
            <i aria-hidden="true" />
            {stateLabel}
          </span>
          <button className="button button-secondary" onClick={exportManifest}>
            JSONを書き出す
          </button>
          <button
            className="button button-primary"
            onClick={() => void saveAndBuild()}
            disabled={saveState === "building"}
          >
            {saveState === "building" ? "ビルド中…" : "保存してビルド"}
          </button>
        </div>
      </header>

      <main className="editor-layout">
        <aside className="parts-panel panel">
          <PanelHeading
            eyebrow="PARTS"
            title="レイヤー"
            trailing={`${manifest.parts.length}`}
          />
          <div className="part-list">
            {[...manifest.parts]
              .sort((left, right) => right.zIndex - left.zIndex)
              .map((part) => (
                <button
                  key={part.id}
                  className={`part-row${
                    part.id === selectedPartId ? " is-selected" : ""
                  }`}
                  onClick={() => setSelectedPartId(part.id)}
                  type="button"
                >
                  <span className="part-thumb">
                    <img
                      src={partImageUrl(part.id, revision)}
                      alt=""
                      draggable={false}
                    />
                  </span>
                  <span className="part-copy">
                    <strong>{part.id}</strong>
                    <small>
                      CELL {part.cell.column}:{part.cell.row}
                    </small>
                  </span>
                  <span className="z-badge">Z{part.zIndex}</span>
                </button>
              ))}
          </div>
          <div className="panel-note">
            <span>操作</span>
            <p>ドラッグまたは矢印キーで1px移動。Shiftキーで4px移動。</p>
          </div>
        </aside>

        <section className="workbench">
          <div className="workbench-toolbar">
            <div className="segmented-control" aria-label="編集対象">
              {(["position", "offset"] as const).map((mode) => (
                <button
                  key={mode}
                  className={editMode === mode ? "is-active" : ""}
                  onClick={() => setEditMode(mode)}
                  type="button"
                >
                  {moveLabels[mode]}
                </button>
              ))}
            </div>
            <div className="frame-readout">
              <span>FRAME</span>
              <strong>{String(frame + 1).padStart(2, "0")}</strong>
              <small>/ {String(manifest.animation.frames).padStart(2, "0")}</small>
            </div>
            <label className="zoom-control">
              <span>表示倍率</span>
              <select
                value={zoom}
                onChange={(event) => setZoom(Number(event.target.value))}
              >
                <option value={4}>4×</option>
                <option value={6}>6×</option>
                <option value={8}>8×</option>
                <option value={10}>10×</option>
              </select>
            </label>
          </div>

          <div className="canvas-zone">
            <SpriteStage
              manifest={manifest}
              frame={frame}
              revision={revision}
              selectedPartId={selectedPartId}
              zoom={zoom}
              referenceUrl={referenceUrl}
              referenceOpacity={referenceOpacity}
              onSelectPart={setSelectedPartId}
              onMovePart={moveSelectedPart}
            />
          </div>

          <section className="timeline-panel" aria-label="アニメーション">
            <div className="playback-controls">
              <button
                className="play-button"
                type="button"
                onClick={() => setPlaying((current) => !current)}
                aria-label={playing ? "停止" : "再生"}
              >
                {playing ? "■" : "▶"}
              </button>
              <div>
                <p>{manifest.animation.name}</p>
                <span>
                  {manifest.animation.fps} FPS ·{" "}
                  {manifest.animation.frames / manifest.animation.fps} SEC
                </span>
              </div>
            </div>
            <div className="frame-strip">
              {Array.from(
                { length: manifest.animation.frames },
                (_, index) => (
                  <button
                    key={index}
                    type="button"
                    className={`frame-cell${
                      frame === index ? " is-current" : ""
                    }`}
                    onClick={() => {
                      setFrame(index);
                      setPlaying(false);
                    }}
                  >
                    <MiniFrame
                      manifest={manifest}
                      frame={index}
                      revision={revision}
                    />
                    <span>{String(index + 1).padStart(2, "0")}</span>
                  </button>
                ),
              )}
            </div>
          </section>
        </section>

        <aside className="inspector-panel panel">
          <PanelHeading eyebrow="INSPECTOR" title="接続と配置" />
          {selectedPart ? (
            <>
              <div className="selected-part-card">
                <span className="selected-part-preview">
                  <img
                    src={partImageUrl(selectedPart.id, revision)}
                    alt=""
                    draggable={false}
                  />
                </span>
                <div>
                  <small>SELECTED PART</small>
                  <strong>{selectedPart.id}</strong>
                  <span>
                    {editMode === "position"
                      ? "全フレームの基準を編集中"
                      : `フレーム${frame + 1}の差分を編集中`}
                  </span>
                </div>
              </div>

              <InspectorGroup title="基準位置" badge="CANVAS">
                <div className="field-grid">
                  <NumberField
                    label="X"
                    value={selectedPart.position.x}
                    onChange={(value) =>
                      changeManifest((current) =>
                        changePartNumber(
                          current,
                          selectedPart.id,
                          "positionX",
                          value,
                        ),
                      )
                    }
                  />
                  <NumberField
                    label="Y"
                    value={selectedPart.position.y}
                    onChange={(value) =>
                      changeManifest((current) =>
                        changePartNumber(
                          current,
                          selectedPart.id,
                          "positionY",
                          value,
                        ),
                      )
                    }
                  />
                </div>
              </InspectorGroup>

              <InspectorGroup title="パーツ内の接続点" badge="ANCHOR">
                <div className="field-grid">
                  <NumberField
                    label="X"
                    value={selectedPart.anchor.x}
                    min={0}
                    max={manifest.grid.logicalCellWidth}
                    onChange={(value) =>
                      changeManifest((current) =>
                        changePartNumber(
                          current,
                          selectedPart.id,
                          "anchorX",
                          value,
                        ),
                      )
                    }
                  />
                  <NumberField
                    label="Y"
                    value={selectedPart.anchor.y}
                    min={0}
                    max={manifest.grid.logicalCellHeight}
                    onChange={(value) =>
                      changeManifest((current) =>
                        changePartNumber(
                          current,
                          selectedPart.id,
                          "anchorY",
                          value,
                        ),
                      )
                    }
                  />
                </div>
                <p className="group-help">
                  キャンバス上の橙色の十字が接続点です。
                </p>
              </InspectorGroup>

              <InspectorGroup
                title={`フレーム ${frame + 1} の移動量`}
                badge="OFFSET"
              >
                <div className="field-grid">
                  <NumberField
                    label="X"
                    value={currentOffset.x}
                    onChange={(value) =>
                      changeManifest((current) =>
                        changeFrameOffset(
                          current,
                          selectedPart.id,
                          frame,
                          "x",
                          value,
                        ),
                      )
                    }
                  />
                  <NumberField
                    label="Y"
                    value={currentOffset.y}
                    onChange={(value) =>
                      changeManifest((current) =>
                        changeFrameOffset(
                          current,
                          selectedPart.id,
                          frame,
                          "y",
                          value,
                        ),
                      )
                    }
                  />
                </div>
              </InspectorGroup>

              <InspectorGroup title="重なり順" badge="LAYER">
                <div className="layer-row">
                  <button
                    type="button"
                    onClick={() =>
                      changeManifest((current) =>
                        updatePart(current, selectedPart.id, (part) => ({
                          ...part,
                          zIndex: part.zIndex - 1,
                        })),
                      )
                    }
                  >
                    −
                  </button>
                  <NumberField
                    label="Z"
                    value={selectedPart.zIndex}
                    onChange={(value) =>
                      changeManifest((current) =>
                        changePartNumber(
                          current,
                          selectedPart.id,
                          "zIndex",
                          value,
                        ),
                      )
                    }
                  />
                  <button
                    type="button"
                    onClick={() =>
                      changeManifest((current) =>
                        updatePart(current, selectedPart.id, (part) => ({
                          ...part,
                          zIndex: part.zIndex + 1,
                        })),
                      )
                    }
                  >
                    ＋
                  </button>
                </div>
              </InspectorGroup>
            </>
          ) : (
            <p className="empty-inspector">パーツを選択してください。</p>
          )}

          <InspectorGroup title="参考画像" badge="OVERLAY">
            <label className="file-button">
              完成イメージを重ねる
              <input type="file" accept="image/png,image/jpeg" onChange={loadReference} />
            </label>
            {referenceUrl ? (
              <div className="opacity-row">
                <label htmlFor="reference-opacity">不透明度</label>
                <input
                  id="reference-opacity"
                  type="range"
                  min="0.05"
                  max="0.9"
                  step="0.05"
                  value={referenceOpacity}
                  onChange={(event) =>
                    setReferenceOpacity(Number(event.target.value))
                  }
                />
                <button
                  type="button"
                  onClick={() => {
                    URL.revokeObjectURL(referenceUrl);
                    setReferenceUrl(null);
                  }}
                >
                  外す
                </button>
              </div>
            ) : null}
          </InspectorGroup>
        </aside>
      </main>

      <footer className={`statusbar status-${saveState}`}>
        <span className="status-light" aria-hidden="true" />
        <p>{message}</p>
        <div>
          <span>SOURCE</span>
          <code>{paths.source}</code>
        </div>
        <div>
          <span>OUTPUT</span>
          <code>{paths.output}</code>
        </div>
      </footer>
    </div>
  );
}

function PanelHeading({
  eyebrow,
  title,
  trailing,
}: {
  eyebrow: string;
  title: string;
  trailing?: string;
}) {
  return (
    <div className="panel-heading">
      <div>
        <span>{eyebrow}</span>
        <h2>{title}</h2>
      </div>
      {trailing ? <strong>{trailing}</strong> : null}
    </div>
  );
}

function InspectorGroup({
  title,
  badge,
  children,
}: {
  title: string;
  badge: string;
  children: ReactNode;
}) {
  return (
    <section className="inspector-group">
      <header>
        <h3>{title}</h3>
        <span>{badge}</span>
      </header>
      {children}
    </section>
  );
}

function NumberField({
  label,
  value,
  min,
  max,
  onChange,
}: {
  label: string;
  value: number;
  min?: number;
  max?: number;
  onChange: (value: number) => void;
}) {
  return (
    <label className="number-field">
      <span>{label}</span>
      <input
        type="number"
        value={value}
        min={min}
        max={max}
        step={1}
        onChange={(event) => {
          const nextValue = Number(event.target.value);
          if (Number.isInteger(nextValue)) {
            onChange(nextValue);
          }
        }}
      />
    </label>
  );
}
