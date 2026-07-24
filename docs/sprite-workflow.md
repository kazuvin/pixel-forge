# Monster Sprite Asset Workflow

## 目的

Codexの`imagegen`で一体分のパーツシートを作り、Pixel Forge CLIで決定的な8フレームの立ちアニメーションへ変換する。画像生成modelやゲームエンジンの都合をRust coreへ持ち込まず、生成後のpixel化、分割、合成、sheet packingだけを再現可能にする。

この機能は個人向けoffline asset compilerであり、iPhoneアプリへ生成AI、animation editor、cloud処理を追加するものではない。

## 構成

```text
monster.sprite.json
  ├─ pixel-forge sprite prompt ─ imagegen-prompt.md
  └─ pixel-forge sprite build
                                  ↑
Codex imagegen ─ chroma-key除去 ─ transparent parts PNG
                                  ↓
pixel-sprite ─ pixel-core ─ parts PNG + idle PNG + metadata + recipe
```

`pixel-core`はparts sheet全体を一度だけ共通の論理解像度とpaletteへ変換する。`pixel-sprite`は論理gridでpartを切り出し、integer offsetで合成する。`pixel-cli`だけがpathとfile I/Oを扱う。

生成後の位置調整には`apps/sprite-editor`を使う。React側は生成済みpartを即時previewするだけで、保存とgame用出力はlocal APIから同じ`pixel-cli sprite build`を呼び出す。

## Codexから生成する

repo内の`$generate-monster-sprite`を使う。

```text
Use $generate-monster-sprite to create a compact stone golem with a wooden club under examples/sprites/my-golem.
```

スキルは次を行う。

1. `examples/sprites/moss-golem/moss-golem.sprite.json`を基にmanifestを作る。
2. `sprite prompt`で標準`imagegen`用promptを生成する。
3. built-in `imagegen`で正方形のchroma-key parts sheetを生成する。
4. `imagegen`スキル同梱のbackground removal helperで透過PNGへ変換する。
5. `sprite validate`と`sprite build`を実行する。
6. 出力sheetを画像として確認し、必要ならmanifestの`anchor`、`position`、`zIndex`、`offsets`を調整して再buildする。

画像生成はPixel ForgeのbinaryやAPIから直接呼ばない。画像生成modelの変更や認証をasset compilerから分離するため、Codex skillをadapterとして利用する。

## CLIを個別に使う

sample manifestを検証する。

```bash
cargo run -p pixel-cli -- sprite validate \
  examples/sprites/moss-golem/moss-golem.sprite.json
```

Codex `imagegen`へ渡すpromptを生成する。

```bash
cargo run -p pixel-cli -- sprite prompt \
  examples/sprites/moss-golem/moss-golem.sprite.json \
  --output examples/sprites/moss-golem/imagegen-prompt.md
```

生成されたchroma-key画像は、`imagegen`スキルの手順に従って透過PNGへ変換する。通常は同スキル同梱の`remove_chroma_key.py`を`--auto-key border --soft-matte --despill`で利用する。

透過PNGからassetを生成する。

```bash
cargo run -p pixel-cli -- sprite build \
  examples/sprites/moss-golem/moss-golem.sprite.json \
  --source examples/sprites/moss-golem/parts.png \
  --output examples/sprites/moss-golem/output
```

## ローカルeditorで位置を調整する

標準では今回生成した岩ゴーレムを開く。

```bash
corepack pnpm sprite-editor:dev
```

別のspriteを開く。

```bash
corepack pnpm --filter @pixel-forge/sprite-editor dev -- \
  --manifest examples/sprites/my-golem/my-golem.sprite.json \
  --source examples/sprites/my-golem/my-golem.parts.png \
  --output examples/sprites/my-golem/output
```

editorは`http://127.0.0.1:4317/`を起点に空いているlocal portで起動する。外部interfaceへbindせず、pathはすべてrepository内へ制限する。

- `基準位置`: `part.position`を全frame共通でドラッグする。
- `このフレーム`: 選択中frameの`part.offsets[index]`だけをドラッグする。
- 矢印キー: 1 logical pixel移動する。Shift + 矢印キーでは4pixel移動する。
- 接続点: `part.anchor`を数値で調整し、canvas上の橙色crosshairで確認する。
- 重なり順: 左のレイヤー一覧で全frame共通順を変更し、選択frameだけの差分は`zIndexDeltas`で変更する。
- モーションシーケンサー: 選択partのX、Y、幅、高さ、重なり差分を8frame横並びで直接編集する。
- 動きプリセット: 静止、呼吸、重量級、小刻み、浮遊をcharacter全体へ適用し、その後にpart単位で調整する。
- サイズ変更: `sizeDeltas`へ元のopaque boundsからのinteger pixel差分を指定する。脚では固定点を`bottom-center`にすると足裏を接地したまま縦へ縮められる。
- 参考画像: 完成イメージをブラウザ内だけで半透明overlayする。
- `JSONを書き出す`: repositoryへ書き込まず、現在のmanifestをbrowser downloadとして出力する。
- `保存してビルド`: 候補manifestのCLI build成功後に元のmanifestを保存し、正規outputを再生成する。

## 出力

`animation.name`が`idle`、`previewScale`が4の場合は次を生成する。

```text
output/
├─ idle.png
├─ idle@4x.png
├─ idle.json
├─ sprite.recipe.json
└─ parts/
   ├─ body.png
   ├─ head.png
   └─ ...
```

- `idle.png`: 透過背景、論理64x64を横8frameに並べたgame用sheet
- `idle@4x.png`: nearest-neighborで拡大した確認用sheet
- `idle.json`: frame size、frame数、fps、各frameのsheet座標
- `sprite.recipe.json`: 入力hash、manifest、pixel-core recipe、sprite algorithm version
- `parts/*.png`: 共通paletteへ変換済みの各part

## Manifest

`schemaVersion` 2では次を指定する。version 1のmanifestもCLIで読み取れ、editorで開くとversion 2へ正規化される。

- `generation`: Codex `imagegen` prompt用の説明、style、view、palette、chroma-key、avoid
- `grid`: imagegenへ要求する見えないgridと、各cellの論理pixel寸法
- `canvas`: 1frameの論理寸法
- `render`: sheet全体へ適用する色数、dither、確認用拡大率
- `animation`: animation名、frame数、fps
- `parts`: part ID、grid cell、part内anchor、canvas上のposition、z-order、frameごとのinteger offset、幅・高さ差分、z-order差分、resize固定点

`anchor`、`position`、`offsets`、`sizeDeltas`はpixel整数とする。resizeはpixel化済みpartのopaque boundsへnearest-neighborを適用し、`resizeAnchor`を固定する。親子transformやsubpixel補間は行わない。同じ入力PNGとmanifestから同じdecode後RGBAとJSONを生成する。

標準idleではheadを`[0, 0, 1, 1, 2, 2, 1, 0]`pixel下げ、bodyとarmを`[0, 0, 1, 1, 1, 1, 0, 0]`pixel下げる。legは足裏を固定し、必要に応じて高さを`[0, 0, 0, -1, -1, -1, 0, 0]`pixel変化させる。

## 生成時の制約

- parts sheetは正方形とし、manifestのrow/columnへ1partずつ置く。
- grid線、label、完成済み全身、animation frameを描かせない。
- 全partで縮尺、正面方向、光源、素材、輪郭を一致させる。
- partをcell境界へ触れさせず、接続端を隠さない。
- 被写体に使わないchroma-key色をmanifestで明示する。
- 背景除去後のsourceはalphaを持つPNGにする。完全opaque画像はCLIが拒否する。
- 腕や脚の本数をcoreへ固定しない。manifestへ任意partを追加する。

## 初版の制限

- 1枚のparts sheetと1 animation clipだけを扱う。
- frameは横一列へpackする。
- transformはinteger translation、opaque boundsのinteger resize、frame z-orderだけとし、回転、自由scale、mesh変形、IKは行わない。
- editorはmask描画、partの回転、自由scale、IK、自動rig推定を行わない。
- Unityなどゲームエンジン固有importerは持たない。
