# アーキテクチャ

```text
macOS SwiftUI app ─ PixelCoreKit ─ pixel-ffi ─┐
                                               ├─ pixel-core ─ PNG + recipe
game asset CLI ─────────────── pixel-cli ──────┘
```

## pixel-core

入力画像をdecodeし、中心crop、縮小、palette抽出、量子化、ディザリング、整数倍拡大、PNG encodeを行う。ファイルパスやUI状態は受け取らず、byte列と設定だけを扱う。

## pixel-ffi

UniFFIが扱えるrecord、enum、errorへ変換する。coreの型とFFI型を分けることで、binding generatorの変更をcoreへ波及させない。

## PixelCoreKit

生成されたbindingをアプリ向けの小さなSwift APIで包む。アプリはUniFFI生成型を直接参照しない。

## pixel-cli

ファイルI/Oと引数解釈だけを担当する。生成PNGの隣にrecipeを保存し、ゲームリポジトリはこのCLIをoffline asset compilerとして呼び出す。

## 決定性

- palette boxの選択、channel選択、sort、tie breakを固定する。
- ランダム初期値を使わない。
- PNG byte列ではなく、decode後RGBAの同一性をcoreの主要契約とする。
- algorithm変更時は`ALGORITHM_VERSION`を更新する。

