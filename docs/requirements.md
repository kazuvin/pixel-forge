# 要求定義

## プロダクト

Pixel Forgeは、写真を機械的かつ再現可能なピクセルアートへ変換するローカルツールである。SwiftUIアプリで設定を試し、同じRustエンジンをCLIからゲームアセット生成にも利用する。

## MVP

- macOSでPNG、JPEG、PPMを読み込める。
- 入力と出力を並べて確認できる。
- 出力幅、高さ、色数、ディザリング、整数倍拡大を指定できる。
- center crop、縮小、減色、ディザリング、nearest-neighbor拡大をRustで処理する。
- PNGと再生成用recipe JSONを書き出せる。
- CLIから同じ変換を実行できる。
- 同じ入力と設定から同じRGBA結果を生成できる。

## MVPに含めない

- 生成AIによる描き直し
- 手描き編集、レイヤー、アニメーション
- クラウド保存、アカウント、課金
- Unity/ゲームエンジン固有importer
- iOS、iPadOS、Windows、Android向けUI
- ICC profileを使った厳密な印刷色管理

## 品質

- coreはSwiftやApple SDKなしでテストできる。
- FFI境界でpanicを外へ漏らさない。
- recipeにalgorithm version、入力hash、全設定、palette、出力寸法を含める。
- UIの出力プレビューはpixel interpolationを無効にする。

