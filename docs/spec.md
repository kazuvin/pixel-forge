# 技術仕様と判断

## ✅ 決定

- Rust Cargo workspaceとSwift Packageを同じリポジトリに置く。
- `pixel-core`を変換仕様の正本にする。
- Swift連携にはUniFFI 0.32を使う。
- Apple向けRust成果物はstatic libraryをXCFrameworkに包む。
- 最初のUI targetはmacOS 14以降とする。
- core APIは同期処理とし、呼び出し側がバックグラウンド実行する。
- v1のcore APIは`PixelSession::convert(RenderSettings)`とする。
- cropは元画像座標の矩形または画像全体で指定し、論理解像度の短辺はcropの縦横比から決定する。
- 透過入力は白へ合成し、v1の出力は常にopaque RGBAとする。
- 元画像色モードでは縮小後の色をそのまま利用する。
- paletteモードでは利用側が名前とRGB色列を渡し、coreはpaletteの永続化やゲーム固有presetを担当しない。
- paletteの近似色探索にはOKLab上の二乗距離を利用する。
- 色調保持ではpalette色の色相を基準に、HSLの彩度と明度を元画像側へ指定割合だけ補間する。無彩色paletteでは元画像の色相を利用する。
- 輪郭検出は縮小後の元画像色を参照し、右/下の隣接pixelとのOKLab色差が閾値を超えた境界の暗い側を1pixelだけマークする。
- すべての輪郭色で2x2の輪郭maskを反復走査し、輪郭3pixelのL字角から頂点を落として斜めに接する2pixelへ整形する。直線と輪郭4pixelのsolid blockは維持する。
- なじむ輪郭色は変換後pixelの色相と彩度を保ち、明度を下げる。
- v1ではディザリングと入力画像からのpalette自動生成を行わない。
- recipe schemaとalgorithm versionはRust側が生成する。
- Git repositoryの初期化とremote設定はユーザーが後から行う。

既存のSwift/CLI adapterが利用する`PixelSession::render(PixelSettings)`は移行用の互換入口とし、v1変換仕様の正本には含めない。

## 🟡 暫定

- 入力上限は80 megapixel、targetは最大1024 x 1024、拡大後は最大16384 pixel/辺とする。
- XCFrameworkは開発マシン向けarm64 macOS sliceから開始する。
- 輪郭閾値は0から100の整数とし、OKLab距離へ線形変換する。

## ❓ 未決

- 製品名、bundle identifier、App Store配布方針
- iPadOS版の追加時期
- 組み込みpalette presetの標準セット
- sprite sheet、透過背景除去、輪郭強調の追加
- crateまたはCLI binaryのゲームリポジトリへの配布方法
