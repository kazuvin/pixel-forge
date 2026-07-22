# 技術仕様と判断

## ✅ 決定

- Rust Cargo workspaceとSwift Packageを同じリポジトリに置く。
- `pixel-core`を変換仕様の正本にする。
- Swift連携にはUniFFI 0.32を使う。
- Apple向けRust成果物はstatic libraryをXCFrameworkに包む。
- 最初のUI targetはmacOS 14以降とする。
- core APIは同期処理とし、呼び出し側がバックグラウンド実行する。
- v1のリサイズは中心基準のcover cropとする。
- palette生成は決定的なweighted median cutとする。
- ディザリングはnone、Bayer 4x4、Floyd-Steinbergを提供する。
- recipe schemaとalgorithm versionはRust側が生成する。
- Git repositoryの初期化とremote設定はユーザーが後から行う。

## 🟡 暫定

- 入力上限は80 megapixel、targetは最大1024 x 1024、拡大後は最大16384 pixel/辺とする。
- XCFrameworkは開発マシン向けarm64 macOS sliceから開始する。
- 色差は単純なsRGB上の二乗距離を利用する。

## ❓ 未決

- 製品名、bundle identifier、App Store配布方針
- iPadOS版の追加時期
- fixed palette presetの標準セット
- sprite sheet、透過背景除去、輪郭強調の追加
- crateまたはCLI binaryのゲームリポジトリへの配布方法

