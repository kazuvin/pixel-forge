# macOS MVP画面仕様

## 目的

対象は写真からゲーム素材を作る個人制作者である。ホームの仕事は生成結果を見つけること、変換モーダルの仕事は一つの画像を調整して結果を確定すること、設定の仕事はアプリ全体の選択とサポート導線をまとめることである。

ナビゲーションを増やさず、制作物、変換操作、アプリ設定の3 surfaceに役割を分ける。pixel workbenchの署名要素は、対角pixel border、square status lamp、pixel grid icon、data labelへ限定する。

## Navigation

```text
Home
├─ New Conversion Modal
│  └─ editing -> rendering -> result / failure
├─ Existing Result Modal
│  └─ result -> editing -> overwrite or create variant
└─ Settings Window
   ├─ Appearance
   ├─ Pixel Forge Pro
   ├─ Support
   └─ About
```

- メインウインドウは一つだけとする。
- タブバー、sidebar navigation、独立したresult windowを設けない。
- modalを重ねず、共通モーダルの状態を切り替える。
- `Escape`は変換中でなければmodalを閉じる。未反映の設定変更がある場合だけ破棄確認を表示する。

## Home

```text
┌──────────────────────────────────────────────────────────┐
│ [PF] PIXEL FORGE                 [設定] [画像を選ぶ]      │
├──────────────────────────────────────────────────────────┤
│  RECENT OUTPUTS / LOCAL LIBRARY                          │
│                                                          │
│  ┌──────────────────────┐  ┌──────────────────────┐      │
│  │ pixel preview        │  │ pixel preview        │      │
│  │                      │  │                      │      │
│  ├──────────────────────┤  ├──────────────────────┤      │
│  │ name        [•••]    │  │ name        [•••]    │      │
│  │ 64×48 / 8x / v1.2.0  │  │ 128×128 / 8x / v1.2 │      │
│  └──────────────────────┘  └──────────────────────┘      │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

### Layout

- toolbarにはbrand、設定、`画像を選ぶ`だけを置く。
- 本文はscroll可能な`LazyVGrid`とし、標準幅では2列、各cardの最低幅を満たせない場合だけ1列にする。
- 列数を3以上へ増やさず、previewとmetadataを読める密度を保つ。
- cardのpreview領域は固定比率とし、縦横比の異なる出力でgridの高さを揺らさない。画像はaspect fit、補間なしで表示する。
- 新しいrecordを先頭へ追加する。既存recordの上書きではcard位置を維持する。

### Empty state

生成結果がない場合はgridの代わりに大きなdrop targetを置く。

- 見出し: `最初の画像を変換する`
- 説明: `PNG、JPEG、PPMをここへドラッグするか、画像を選んでください。`
- 主操作: `画像を選ぶ`
- account、cloud、uploadを想起させる文言を使わない。

### Generated image card

card全体の選択で共通モーダルのresultを開く。cardへ表示する情報は次に限定する。

- 出力preview
- sourceから導いた表示名
- 論理寸法と保存寸法
- algorithm version

overflow menuは`開く`、`PNG＋recipeを書き出す`、`削除`を持つ。menu操作ではcard tapを発火させない。削除は確認し、外部書き出し済みファイルへ影響しないことを明示する。

## Conversion modal

modalはおおむね980×680ptを基準とし、ホームより前面に一つだけ表示する。

### Editing

```text
┌─────────────────────────────────────────────────────────────┐
│ NEW CONVERSION / source.png                          [×]     │
├──────────────────────────────────┬──────────────────────────┤
│ SOURCE                           │ CONVERSION SETTINGS      │
│                                  │ crop                     │
│ image + crop overlay             │ logical long side        │
│                                  │ upscale                  │
│                                  │ color / palette          │
│                                  │ outline                  │
│                                  │                          │
├──────────────────────────────────┴──────────────────────────┤
│ output estimate                    [キャンセル] [変換する]   │
└─────────────────────────────────────────────────────────────┘
```

- source preview上で矩形cropを直接調整できる。全体cropへ戻す操作を用意する。
- controlsは`Geometry`、`Color`、`Outline`の順に並べ、core pipelineと同じ順序にする。
- 無料版で利用できないcontrolも表示し、lockと`PRO` markerを付ける。
- locked controlを選ぶとPro purchase sheetを開く。購入をcancelしてもcropと無料設定を失わない。
- 新規変換の主操作は`変換する`とする。
- 既存recordの調整では`別の画像として保存`を副操作、`この画像を更新`を主操作とする。

### Rendering

- 変換開始から200msまではediting surfaceを維持し、controlと実行ボタンだけを無効化する。
- 200msを超えた場合はpreview上へpixel scanを想起させる不定進捗を一つだけ表示する。
- percentageを推測せず、処理を長く見せるminimum durationを設けない。
- Reduce Motionではanimationを止め、status lampと`変換中`だけを表示する。

### Result

```text
┌─────────────────────────────────────────────────────────────┐
│ RESULT / source.png / ALGORITHM 1.2.0                 [×]   │
├───────────────────────────┬─────────────────────────────────┤
│ INPUT                     │ OUTPUT                          │
│ source + crop             │ nearest-neighbor preview        │
│                           │                                 │
├───────────────────────────┴─────────────────────────────────┤
│ 64×48 logical / 512×384 output / source colors              │
│ [設定を調整]       [PNG＋recipeを書き出す]                   │
└─────────────────────────────────────────────────────────────┘
```

- resultは新規変換完了後とホームcard選択の両方で同じ構成にする。
- inputは適用cropを示し、outputは必ず補間なしで表示する。
- 詳細metadataにはschema version、algorithm version、palette名、outline、作成日時、更新日時を表示する。
- `設定を調整`は同じmodalをeditingへ戻し、既存recipeを初期値にする。
- 書き出しはPNGとrecipeを同時に保存する。

### Failure

- modalを閉じず、入力と設定を維持する。
- 何が失敗したかと、ユーザーが次にできることを具体的に表示する。
- `もう一度変換`と`設定へ戻る`を用意する。
- 既存recordの更新失敗では、以前の結果が保持されていることを表示する。

## Pro purchase sheet

- 商品は買い切りの`Pixel Forge Pro`一つだけを表示する。
- 解放される現在の機能、価格、買い切りであること、購入の復元を明示する。
- subscription、期間、無料trial、広告非表示を表示しない。
- 主操作はStoreKitから取得したlocalized priceを含む`Proを購入`、副操作は`購入を復元`とする。
- purchase、pending、cancel、failure、successをsheet内で扱い、success後は元のediting controlへ戻す。

## Settings

```text
┌────────────────────────────────────────────────────┐
│ SETTINGS                                           │
│                                                    │
│ APPEARANCE                                         │
│ (●) macOSに合わせる  ( ) 黒基調 PRO  ( ) 白基調 PRO │
│                                                    │
│ PIXEL FORGE PRO                                    │
│ 購入状態 / Proを購入 / 購入を復元                  │
│                                                    │
│ SUPPORT                                            │
│ App Storeでレビュー          >                     │
│ Pixel Forgeをシェア          >                     │
│ ご意見・ご要望               ↗                     │
│ プライバシーポリシー         ↗                     │
│ 利用規約                       ↗                     │
│                                                    │
│ ABOUT                                              │
│ Version 1.0.0 (1)                                  │
└────────────────────────────────────────────────────┘
```

- Appearanceは無料版でもmacOSの外観へ追従し、Proだけがdark/lightを手動固定できる。
- `App Storeでレビュー`は公開済みproduct pageを開く。アプリ起動直後にreview promptを出さない。
- shareは公開済みApp Store URLを対象にする。
- Googleフォーム、privacy、termsは外部ブラウザで現在言語のURLを開く。
- versionは`CFBundleShortVersionString`、buildは`CFBundleVersion`から表示する。

## Accessibility / keyboard

- すべてのicon buttonへ日英のaccessibility labelとhelpを付ける。
- lock状態を色だけで表現しない。
- keyboard focus順は見た目の上から下、左から右と一致させる。
- `Command-O`で画像選択、`Command-,`で設定、`Command-S`でresult書き出しを行う。
- 画像previewにはsource名、論理寸法、保存寸法を含むaccessibility descriptionを付ける。
- system、dark、lightのすべてでcontrastとfocus ringを確認する。

## Review states

最低限、次の状態を日英、dark/lightで確認する。

- Home empty
- Home with two or more cards
- New conversion editing: free
- New conversion editing: Pro
- Rendering over 200ms
- Result
- Failure
- Pro purchase: available、pending、purchased、failure
- Settings: free、Pro
