# アーキテクチャ

```text
iPhone portrait SwiftUI app
├─ Home / Conversion Modal / Settings
├─ local library ─ SourceAsset + GeneratedImageRecord
├─ StoreKit 2 ─ Pixel Forge Pro entitlement
└─ PixelCoreKit ─ pixel-ffi ─┐
                              ├─ pixel-core ─ PNG + recipe
personal CLI ─ pixel-cli ────┘

Astro static site ─ dist ─ Cloudflare Workers Static Assets
```

## pixel-core

入力画像をdecodeし、非破壊crop、縦横比を維持した縮小、明示paletteへの知覚的色変換、色調保持、輪郭検出、整数倍拡大、PNG encodeを行う。ファイルパス、UI状態、paletteの永続化、課金状態は受け持たず、byte列と値として完結した設定だけを扱う。

変換は検証済み設定を入口にしたpipelineとして構成し、crop/resize、color strategy、outline、upscale、encodeの順序を固定する。カラーモードと輪郭モードはRustのenum dispatchを使い、無効な組み合わせを文字列やnullable fieldで表現しない。

## pixel-ffi

UniFFIが扱えるrecord、enum、errorへ変換する。coreの型とFFI型を分けることで、binding generatorの変更をcoreへ波及させない。StoreKitやPro機能の判定は行わない。

## PixelCoreKit

生成されたbindingをアプリ向けの小さなSwift APIで包む。アプリはUniFFI生成型を直接参照しない。同期core APIをSwift concurrencyから安全に呼び出せるadapterを提供するが、画面状態と購入状態は保持しない。

## iPhone app

SwiftUIアプリは次を担当する。

- ホーム、変換モーダル、設定のnavigationと状態管理
- source assetと生成recordのlocal persistence
- background taskでの変換実行
- PNGとrecipeの共有シート書き出し
- StoreKit 2 entitlementとPro capability判定
- 日英localization、system/dark/light theme、accessibility

Pro判定はSwift app layerだけに閉じる。Rustへ渡す`RenderSettings`は購入経路に関係なく同じ型とし、無料版で選択可能な設定範囲をSwift側で制御する。

## local library

```text
SourceAsset(input SHA-256, original bytes)
  ├─ GeneratedImageRecord A(PNG, recipe, metadata)
  ├─ GeneratedImageRecord B(PNG, recipe, metadata)
  └─ GeneratedImageRecord C(PNG, recipe, metadata)
```

source assetはhashで重複排除する。生成recordの更新は成功結果を一時保存してから差し替え、失敗時は既存recordを維持する。最後の参照recordが削除されたsourceだけを回収する。

## pixel-cli

ファイルI/Oと引数解釈だけを担当する。生成PNGの隣にrecipeを保存し、個人のゲームリポジトリからoffline asset compilerとして呼び出す。MVPでは一般配布せず、StoreKitやiPhoneアプリのPro判定を共有しない。

## support web

`apps/web`はAstroで日英のsupport、privacy、termsを静的生成する。Cloudflare Workers Static Assetsは`dist`を直接配信し、Worker scriptやSSRを介在させない。アプリは安定したcustom domainのURLを外部ブラウザで開き、Googleフォームはsupport pageから明示的に外部遷移させる。

## 決定性

- palette色の近似距離が同じ場合は、設定されたpaletteで先に現れる色を選ぶ。
- 輪郭の走査順、隣接方向、同明度時のmark側を固定する。
- ランダム初期値を使わない。
- PNG byte列ではなく、decode後RGBAの同一性をcoreの主要契約とする。
- algorithm変更時は`ALGORITHM_VERSION`を更新する。
- アプリ更新時に既存recordを自動再変換しない。
