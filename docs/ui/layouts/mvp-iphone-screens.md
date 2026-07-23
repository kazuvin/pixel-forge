# iPhone MVP画面仕様

## 対象と原則

Pixel ForgeのUIはiOS 17以降のiPhone縦向きだけを対象とする。iPad、横向き、Mac Catalyst、Designed for iPad on MacはMVPに含めない。

ホームは生成結果を見つける場所、全画面の変換フローは一つの画像を調整して結果を確定する場所、設定は言語・外観・購入・サポートをまとめる場所とする。タブバーを設けず、片手で上から下へ読める順序を保つ。

## Navigation

```text
Home
├─ New Conversion (full screen)
│  ├─ Style Picker / Advanced Settings
│  └─ editing -> rendering -> result / failure
├─ Existing Result (same full screen)
│  └─ result -> editing -> update or save as new
└─ Settings (full screen)
   ├─ Language
   ├─ Appearance
   ├─ Pixel Forge Pro
   ├─ Support
   └─ About
```

- 起点はHomeだけとし、tab barを置かない。
- 変換は新規・既存とも同じfull-screen coverを使い、状態ごとに別画面を重ねない。
- SettingsはHomeからfull-screen coverで開き、専用の閉じる操作でHomeへ戻る。横方向の戻るgestureは提供しない。
- 変換中はinteractive dismissalを無効にし、重複実行を許可しない。

## Home

```text
┌───────────────────────────┐
│ [PF] Pixel Forge  [≡] [+] │
│      local library        │
├───────────────────────────┤
│ ┌──────────┐ ┌──────────┐ │
│ │ preview  │ │ preview  │ │
│ ├──────────┤ ├──────────┤ │
│ │ name [×] │ │ name [×] │ │
│ │ metadata │ │ metadata │ │
│ └──────────┘ └──────────┘ │
│                           │
├───────────────────────────┤
│ local library / count     │
└───────────────────────────┘
```

- safe area直下のtop barにはbrand、設定、画像追加だけを置く。
- 画像追加はpixel UIのメニューをアニメーション付きで開き、利用可能な場合は`カメラで撮る`、`写真を選ぶ`、`ファイルから選ぶ`を分けてこの順に表示する。
- 撮影完了後は撮影画像を入力した共通変換フローのeditingを開く。撮影画像を写真ライブラリへ自動保存しない。
- 初回の撮影操作でカメラ権限を要求する。拒否または制限時は理由とiOS設定への導線を表示し、カメラがない環境では撮影項目を表示しない。
- 生成結果は新しい順で常に2列の`LazyVGrid`へ表示する。
- previewとmetadata領域の高さを揃え、文字量が異なってもcard全体の高さを統一する。画像はaspect fitかつ補間なしで表示する。
- card全体のtapで共通変換フローのresultを開く。card内に削除buttonを置かない。
- cardを長押しすると振動後にpixel UIの操作dialogをアニメーション付きで表示し、`調整する`、`写真に保存`、`複製する`、`削除する`を選べる。複製は同じ設定と生成物を新しいlibrary recordとして追加し、削除選択時は続けて確認dialogを表示する。
- cardの更新日時は選択中の言語と地域に合わせて表示する。
- 下端にはローカル保存であることと件数を短く表示する。

### Empty

- 見出し: `最初の画像を作りましょう`
- 説明: カメラ撮影、写真ライブラリ、Filesを利用できること、処理がiPhone内で完結することを示す。
- 主操作: `画像を選ぶ`
- upload、account、cloudを想起させる表現を使わない。

## Conversion: editing

```text
┌───────────────────────────┐
│ [PF] source.png        [×]│
│      1200 × 900 px        │
├───────────────────────────┤
│ OUTPUT / LIVE             │
│ ┌───────────────────────┐ │
│ │ pinned output preview │ │
│ └───────────────────────┘ │
├───────────────────────────┤
│ 現在: スタンダード        │
│              [読込][保存] │
│ カラーパレット            │
│ [元画像][GB][PICO][…] →   │
│ [＋ 詳細調整]             │
├───────────────────────────┤
│ [保存/更新][写真][共有]…  │
└───────────────────────────┘
```

- 入力previewはeditingへ表示しない。出力previewをtop bar直下へ固定し、下側の設定領域だけを縦scroll可能にする。
- 出力previewは選択中presetと詳細値へリアルタイムに追従する。連続変更は短くdebounceし、preview変換を直列化して最新設定の結果だけを表示する。previewの更新だけではlibrary recordを作成または更新しない。
- 内蔵変換スタイルと保存済み調整プリセットは小型の`読み込む`から選び、現在の調整値は小型の`保存`から名前付きpresetとして保存・管理する。同じ行の左側へ現在の調整名を表示し、値がpresetと一致しなくなった場合は`カスタム調整`と表示する。
- 元画像色、custom、33種類の組み込みpaletteは小型cardの横scroll railへ並べる。cardはpalette名、色数、使用色の小さなswatch、lock、選択状態だけを示し、pixel参考画像や説明文を重ねない。customは組み込みpaletteより前へ置き、長いrailでもすぐ編集できるようにする。
- 実機・規格系paletteは原典の色数を維持し、創作系は2〜3系統を同数で構成する。cardのswatchは色数に応じて1〜4段へ自動配置し、64色まで省略せず表示する。
- palette railは親surfaceの左右paddingを打ち消してsurface端までscroll領域を広げ、先頭と末尾へ同じpaddingをscroll contentとして戻す。親paddingでcardが見切れた状態にはしない。
- 論理解像度、拡大率、paletteの適用方法、輪郭は上級者向けの`詳細調整`内へ表示する。palette選択そのものは詳細調整へ重複配置しない。
- 切り抜き機能は置かず、入力画像全体を対象にする。
- 数値は直接入力でき、増減buttonの長押しとtrackの水平scrubでも連続変更できる。
- palette cardのtapは選択を出力previewへ即時反映する。custom cardはfull-screen pickerを開き、色を追加、編集、削除できる。
- custom paletteではカンマ区切り入力を使わず、SwiftUI標準のカラーピッカーから色を1色ずつ追加、編集、削除する。
- palette適用と輪郭modeはpixel preview付きcardで選択し、文言だけに依存しない。
- 無料範囲外の設定も隠さずlockを表示する。選択時にProが必要であることを説明し、現在の入力と設定を失わない。
- 新規変換の主操作は`画像を保存`とする。
- 既存recordの調整では`この画像を更新`を主操作、`別の画像として保存`を副操作として同時に提示する。
- editing下端には保存／更新、写真保存、画像共有を固定表示し、既存recordでは別画像保存、複製、削除も加える。幅が足りない場合はiconだけにし、accessibility labelで操作名を保持する。
- touch targetは44pt以上とし、lockや選択状態を色だけで示さない。

## Conversion: rendering / failure

- 変換開始から200ms以内に完了した場合はloadingを表示せずresultへ切り替える。
- 200msを超えた場合だけ不定進捗と`変換中`を表示し、見せるための待ち時間を追加しない。
- 処理はUI thread外で実行する。MVPでは変換を閉じてHomeへ戻すbackground queueや複数並列変換を持たない。
- failureでは入力と設定を保持し、既存recordの更新失敗なら以前の結果が残っていることを表示する。

## Conversion: result

```text
┌───────────────────────────┐
│ [PF] source.png        [×]│
├───────────────────────────┤
│ INPUT                     │
│ ┌───────────────────────┐ │
│ │ source                │ │
│ └───────────────────────┘ │
│ OUTPUT                    │
│ ┌───────────────────────┐ │
│ │ pixel result          │ │
│ └───────────────────────┘ │
│ size / palette / version  │
│ [調整する] [写真に保存]   │
│ [複製]     [削除]         │
└───────────────────────────┘
```

- 新規変換完了後とHomeのcard tapで同じresultを表示する。
- inputとoutputを縦に比較し、outputは補間なしで表示する。
- 論理寸法、保存寸法、palette、algorithm versionを表示する。
- `調整する`で同じfull-screen coverをeditingへ戻し、保存済みrecipeの全パラメータと内蔵／保存済みプリセットの選択状態を復元する。
- 保存はPNG画像だけをPhotosの追加専用権限で写真アプリへ追加し、成功または失敗を同じresult内に表示する。recipe JSONは外部へ渡さない。
- Homeの長押しdialogと同じく、result内から調整、写真保存、画像共有、複製、削除を実行できる。

## Settings

```text
┌───────────────────────────┐
│ [PF] 設定              [×]│
├───────────────────────────┤
│ LANGUAGE                  │
│ [現在の言語         ▣]    │
│                           │
│ APPEARANCE                │
│ iOSに合わせる             │
│ 黒基調 PRO                │
│ 白基調 PRO                │
│                           │
│ PIXEL FORGE PRO           │
│ purchase / restore        │
│                           │
│ SUPPORT / ABOUT           │
└───────────────────────────┘
```

- 言語の初期値は`システムデフォルト`とし、pixel selectorから`English`、`日本語`、`한국어`、`繁體中文（台灣）`へ手動固定できる。
- system時はiOSの最優先言語だけを評価し、対応言語ならその言語、それ以外なら英語へfallbackする。
- 言語変更はその場で画面文言とsupport URLへ反映し、再起動後も保持する。
- 無料版はiOS appearanceへの自動追従を利用でき、Proはdark/lightを手動固定できる。
- Supportにはレビュー、シェア、Googleフォーム、privacy、termsを置き、Aboutにはversionとbuildを表示する。
- `PixelForgeApp-Developer` schemeで起動した場合だけ、StoreKitへ影響しないFree / Pro切替を表示する。

## Portrait / accessibility contract

- app targetは`TARGETED_DEVICE_FAMILY = 1`、`SUPPORTS_MACCATALYST = NO`とする。
- `UISupportedInterfaceOrientations`は`UIInterfaceOrientationPortrait`だけを含める。
- すべてのicon buttonに4言語のaccessibility labelを付ける。
- Dynamic Typeによる極端な崩れ、VoiceOver順序、dark/light contrast、Reduce Motionをrelease前に実機確認する。
- 小さいiPhoneでも2列gridを維持し、card名は省略、重要metadataは複数行で表示する。

## Review screenshots

次の28枚をiPhone Simulatorの縦向きで保存する。

- `pixel-forge-home--{dark,light}.png`
- `pixel-forge-image-source-menu--{dark,light}.png`
- `pixel-forge-record-action-dialog--{dark,light}.png`
- `pixel-forge-delete-dialog--{dark,light}.png`
- `pixel-forge-conversion-editing--{dark,light}.png`
- `pixel-forge-conversion-advanced--{dark,light}.png`
- `pixel-forge-conversion-style-picker--{dark,light}.png`
- `pixel-forge-palette-picker--{dark,light}.png`
- `pixel-forge-recipe-preset-library--{dark,light}.png`
- `pixel-forge-recipe-preset-notifications--{dark,light}.png`
- `pixel-forge-conversion-result--{dark,light}.png`
- `pixel-forge-settings--{dark,light}.png`
- `pixel-forge-settings-language-selector--{dark,light}.png`
- `pixel-forge-settings-developer--{dark,light}.png`

自動取得は`./scripts/capture-apple-review.sh`を使う。
