# Pixel Forge

写真を決定的な手順でピクセルアートへ変換する、Rust製エンジンとiPhone SwiftUIアプリのワークスペースです。

## 構成

- `crates/pixel-core`: 画像変換の正本。Apple APIやFFIに依存しません。
- `crates/pixel-sprite`: 透過パーツの分割、8フレーム合成、sprite sheet packingを行います。
- `crates/pixel-cli`: ゲームアセットをバッチ生成するCLIです。
- `crates/pixel-ffi`: UniFFIを使ってRust APIをSwiftへ公開します。
- `packages/PixelCoreKit`: 生成されたSwift bindingとXCFrameworkを包むSwift Packageです。
- `apps/apple/PixelForgeApp`: 入力、比較、設定、PNG画像の写真アプリ保存を行うiPhone縦向き専用のSwiftUIアプリです。
- `apps/sprite-editor`: sprite manifestをドラッグ調整してCLIで再ビルドするローカル専用Reactツールです。
- `apps/web`: 日英のsupport、privacy、termsを静的生成するAstroサイトです。

SwiftUIアプリは黒基調・白基調のtheme、日英localization、DotGothic16を使う共通design systemを持ちます。実装境界とUI変更手順は[`docs/design-system.md`](docs/design-system.md)と[`docs/ui-workflow.md`](docs/ui-workflow.md)を参照してください。

## 最初の実行

```bash
./scripts/build-apple.sh
open apps/apple/PixelForgeApp/PixelForgeApp.xcodeproj
```

StoreKitを使わずにFree / Pro表示を確認する場合は、Xcodeで`PixelForgeApp-Developer` schemeを選ぶ。専用の`Developer` build configurationでだけ、設定画面に切替スイッチが表示されます。

サポートWebはNode 24.14.0（`.mise.toml`）とpnpmを使用します。

```bash
corepack pnpm install
corepack pnpm web:test
corepack pnpm web:check
corepack pnpm web:build
corepack pnpm --filter @pixel-forge/web deploy:dry-run
```

公開前に、アプリ起動環境へ次を設定する。未設定の外部リンクは設定画面で無効表示になり、誤ったURLを開きません。

```text
PIXEL_FORGE_PRO_PRODUCT_ID
PIXEL_FORGE_APP_STORE_URL
PIXEL_FORGE_FEEDBACK_URL
PIXEL_FORGE_WEB_BASE_URL
```

Astro build時は対応する`PUBLIC_FEEDBACK_URL`と`PUBLIC_APP_STORE_URL`を設定します。正式な商品identifier、custom domain、GoogleフォームURL、運営者表記はApp Store公開前の未決事項です。

CLIはApple向け成果物を作らなくても利用できます。

```bash
cargo run -p pixel-cli -- \
  convert \
  fixtures/source-gradient.ppm \
  --output /tmp/pixel-forge-preview.png \
  --width 32 \
  --height 32 \
  --colors 8 \
  --dither bayer4x4 \
  --scale 8
```

Codex `imagegen`からmonster parts sheetを作り、8-frame sprite assetへ変換する手順は[`docs/sprite-workflow.md`](docs/sprite-workflow.md)を参照してください。

```bash
cargo run -p pixel-cli -- sprite validate \
  examples/sprites/moss-golem/moss-golem.sprite.json

cargo run -p pixel-cli -- sprite prompt \
  examples/sprites/moss-golem/moss-golem.sprite.json \
  --output examples/sprites/moss-golem/imagegen-prompt.md

cargo run -p pixel-cli -- sprite build \
  examples/sprites/moss-golem/moss-golem.sprite.json \
  --source examples/sprites/moss-golem/parts.png \
  --output examples/sprites/moss-golem/output
```

生成後のパーツ位置はローカル専用のSprite Rig Editorで調整できます。標準では岩ゴーレムを開き、`127.0.0.1`以外へbindしません。

```bash
corepack pnpm sprite-editor:dev
```

別のmonsterを開く場合はmanifest、透過parts sheet、出力directoryをrepository rootからの相対pathで渡します。

```bash
corepack pnpm --filter @pixel-forge/sprite-editor dev -- \
  --manifest examples/sprites/my-golem/my-golem.sprite.json \
  --source examples/sprites/my-golem/my-golem.parts.png \
  --output examples/sprites/my-golem/output
```

画面ではpartをドラッグまたは矢印キーで1pxずつ移動し、基準位置とframe固有offsetを切り替えられます。`保存してビルド`は候補manifestを一時directoryで検証・buildしてから元のmanifestへ保存し、同じRust CLIでgame用PNGを再生成します。

完了前の品質ゲートは次の1コマンドです。

```bash
./scripts/ci-local.sh
```

## Rust core API

初版仕様の変換入口は`PixelSession::convert(RenderSettings)`です。`RenderSettings`へcrop、長辺解像度、明示paletteと色調保持、輪郭、整数倍拡大を値として渡し、PNGとschema v2 recipeを受け取ります。ファイルI/O、paletteの保存、UI状態はcoreに含めません。

既存CLIとSwift adapterが利用している`PixelSession::render(PixelSettings)`は移行用の互換入口です。

要件と設計判断は [`docs/requirements.md`](docs/requirements.md) と [`docs/spec.md`](docs/spec.md)、iPhone画面は [`docs/ui/layouts/mvp-iphone-screens.md`](docs/ui/layouts/mvp-iphone-screens.md)、Astro/CloudflareのサポートWebは [`docs/web-spec.md`](docs/web-spec.md)、Git導入は [`docs/git-setup.md`](docs/git-setup.md) を参照してください。
