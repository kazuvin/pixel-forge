# アーキテクチャ

```text
macOS SwiftUI app ─ PixelCoreKit ─ pixel-ffi ─┐
                                               ├─ pixel-core ─ PNG + recipe
game asset CLI ─────────────── pixel-cli ──────┘
```

## pixel-core

入力画像をdecodeし、非破壊crop、縦横比を維持した縮小、明示paletteへの知覚的色変換、色調保持、輪郭検出、整数倍拡大、PNG encodeを行う。ファイルパス、UI状態、paletteの永続化は受け持たず、byte列と値として完結した設定だけを扱う。

変換は検証済み設定を入口にしたpipelineとして構成し、crop/resize、color strategy、outline、upscale、encodeの順序を固定する。カラーモードと輪郭モードはRustのenum dispatchを使い、無効な組み合わせを文字列やnullable fieldで表現しない。

## pixel-ffi

UniFFIが扱えるrecord、enum、errorへ変換する。coreの型とFFI型を分けることで、binding generatorの変更をcoreへ波及させない。

## PixelCoreKit

生成されたbindingをアプリ向けの小さなSwift APIで包む。アプリはUniFFI生成型を直接参照しない。

## pixel-cli

ファイルI/Oと引数解釈だけを担当する。生成PNGの隣にrecipeを保存し、ゲームリポジトリはこのCLIをoffline asset compilerとして呼び出す。

## 決定性

- palette色の近似距離が同じ場合は、設定されたpaletteで先に現れる色を選ぶ。
- 輪郭の走査順、隣接方向、同明度時のmark側を固定する。
- ランダム初期値を使わない。
- PNG byte列ではなく、decode後RGBAの同一性をcoreの主要契約とする。
- algorithm変更時は`ALGORITHM_VERSION`を更新する。
