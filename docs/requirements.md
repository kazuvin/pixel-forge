# 要求定義

## プロダクト

Pixel Forgeは、写真を機械的かつ再現可能なピクセルアートへ変換するローカルツールである。SwiftUIアプリで設定を試し、同じRustエンジンをCLIからゲームアセット生成にも利用する。

## MVP

- macOSでPNG、JPEG、PPMを読み込める。
- 入力と出力を並べて確認できる。
- 元画像全体または任意の矩形を、元画像を変更せずcropとして指定できる。
- 論理解像度はcrop後の長辺で指定し、短辺は縦横比から決定する。
- 元画像色、または明示的な組み込み/カスタムpaletteを利用できる。
- paletteは厳密適用と、彩度/明度を割合指定で残す適用を選べる。
- 輪郭線なし、黒、周辺色になじむ暗色を選び、検出閾値を調整できる。
- crop、縮小、色変換、輪郭検出、nearest-neighbor整数倍拡大をRustで処理する。
- PNGと再生成用recipe JSONを書き出せる。
- CLIから同じ変換を実行できる。
- 同じ入力と設定から同じRGBA結果を生成できる。
- 表示設定から黒基調と白基調のテーマを即時切り替えられる。
- 日本語と英語のUI文言を持ち、macOSの優先言語に追従する。
- 日本語と英語を収録する同一のピクセル系fontでUIを表示する。

## MVPに含めない

- 生成AIによる描き直し
- 手描き編集、レイヤー、アニメーション
- クラウド保存、アカウント、課金
- Unity/ゲームエンジン固有importer
- iOS、iPadOS、Windows、Android向けUI
- ICC profileを使った厳密な印刷色管理
- 透過背景の維持または背景除去
- ディザリング
- 入力画像からのpalette自動生成

## 品質

- coreはSwiftやApple SDKなしでテストできる。
- FFI境界でpanicを外へ漏らさない。
- recipeにschema version、algorithm version、入力hash、全設定、palette、論理/保存寸法を含める。
- UIの出力プレビューはpixel interpolationを無効にする。
