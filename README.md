# Pixel Forge

写真を決定的な手順でピクセルアートへ変換する、Rust製エンジンとmacOS SwiftUIアプリのワークスペースです。

## 構成

- `crates/pixel-core`: 画像変換の正本。Apple APIやFFIに依存しません。
- `crates/pixel-cli`: ゲームアセットをバッチ生成するCLIです。
- `crates/pixel-ffi`: UniFFIを使ってRust APIをSwiftへ公開します。
- `packages/PixelCoreKit`: 生成されたSwift bindingとXCFrameworkを包むSwift Packageです。
- `apps/apple/PixelForgeApp`: 入力、比較、設定、PNG/recipe書き出しを行うmacOS SwiftUIアプリです。

## 最初の実行

```bash
./scripts/build-apple.sh
swift run --package-path apps/apple/PixelForgeApp PixelForgeApp
```

CLIはApple向け成果物を作らなくても利用できます。

```bash
cargo run -p pixel-cli -- \
  fixtures/source-gradient.ppm \
  --output /tmp/pixel-forge-preview.png \
  --width 32 \
  --height 32 \
  --colors 8 \
  --dither bayer4x4 \
  --scale 8
```

完了前の品質ゲートは次の1コマンドです。

```bash
./scripts/ci-local.sh
```

要件と設計判断は [`docs/requirements.md`](docs/requirements.md) と [`docs/spec.md`](docs/spec.md)、Git導入は [`docs/git-setup.md`](docs/git-setup.md) を参照してください。

