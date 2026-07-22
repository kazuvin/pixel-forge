# UIワークフロー

## 方向性

対象は写真をゲーム素材へ変換する個人制作者。画面の仕事は、入力と出力の差、出力寸法、recipeを一目で確認し、安全に書き出すこと。

参考ビジュアルから、一般的なmacOS utilityではなく、制作機器の操作盤を思わせるpixel workbenchを採用する。対角pixelで面取りした細枠、square status lamp、密度のあるdata label、pixel grid iconを署名要素とし、装飾はその1系統に限定する。

## Visual system

色は`ForgeDesignTokens.swift`の`ForgePalette`を正本とする。

| Token | Dark | Light | 用途 |
|---|---:|---:|---|
| Canvas | `#11141B` | `#F2F0E8` | 画像比較の作業面 |
| Panel | `#191E29` | `#E5E1D5` | recipe controls / toolbar |
| Surface | `#242B3B` | `#FBFAF5` | controlとpreview背景 |
| Ink | `#F5F3EE` | `#1B202A` | 主要テキスト |
| Muted | `#9BA5B7` | `#657080` | metadata |
| Accent | `#EF7A9E` | `#BC3F66` | 実行、選択、状態lamp |
| Grid | `#66728E` | `#8D98AA` | pixel frame / checker |

- theme差分はpaletteだけに閉じ、layout、spacing、component treeを分岐させない。
- gradient、glass、装飾目的のshadow、連続的な大きなcorner radiusを使わない。
- surfaceの面は`ForgePixelChamferShape`で45度に切り、borderの斜線は`ForgePixelBorder`で角だけが接する独立square pixel列として描く。
- 斜線を水平・垂直rectのL字連続で疑似表現しない。通常の`RoundedRectangle`と自動`stroke`もpixel UI枠には使わない。
- iconは`ForgeIcon`へ16×16のpixel gridとして定義し、SF Symbolsを直接使わない。
- 出力画像は`.interpolation(.none)`で表示する。

## Typography / localization

- UI fontはDotGothic16をSwift Package resourceとして同梱する。
- DotGothic16は日本語・Latinを収録し、ライセンスは`Resources/Fonts/OFL.txt`を同梱する。
- font size、trackingは`ForgeTypography.swift`の`ForgeTextStyle`だけを使う。
- 文言は`Resources/ja.lproj/Localizable.strings`と`en.lproj/Localizable.strings`へ同じkeyで追加する。
- app内へ言語切替を重複実装せず、macOSの優先言語へ追従する。

## Layout

```text
┌───────────────────────────────────────────────┬─────────────────┐
│ [PF] PIXEL FORGE           [設定] [写真を選ぶ] │ RECIPE / VERSION│
├───────────────────────┬───────────────────────┤ size / colors   │
│ INPUT                 │ OUTPUT                │ dither          │
│ source image          │ nearest-neighbor      │                 │
│                       │ pixel preview         │ [変換する]      │
├───────────────────────┴───────────────────────┤ [書き出す]      │
│ ■ STATUS / source / LOCAL + DETERMINISTIC     │                 │
└───────────────────────────────────────────────┴─────────────────┘
```

## 実装境界

```text
ForgePalette / spacing / size
            ↓
Forge typography / chamfer fill / diagonal pixel border / pixel icon
            ↓
Forge top bar / preview / stepper / sidebar / status strip
            ↓
WorkbenchView / ThemeSettingsView（状態と配置だけ）
```

- token、theme、typographyは`Design/ForgeDesignTokens.swift`と`ForgeTypography.swift`を正本にする。
- 再利用可能な見た目とinteractionは`Design/ForgeComponents.swift`へ置く。
- `Screens/`では画面状態、data binding、layout compositionだけを扱う。
- screenへ`Color(...)`、`.font(...)`、`.foregroundStyle(...)`、`.background(...)`、独自`ButtonStyle`を追加しない。
- 新しい見た目が必要なら、既存の`Forge*` componentで表現できない理由を確認してからDesign層へ追加する。
- 変換中は重複実行を防ぎ、exportはPNGとrecipeを同時に保存する。

## 変更手順

1. `docs/requirements.md`、`docs/spec.md`、この文書を読む。
2. 既存のDesign token/componentで画面を構成できるか確認する。
3. 不足する場合だけDesign層へ汎用APIとして追加する。
4. Screen層では共通部品の組み合わせと状態接続だけを行う。
5. `./scripts/verify-apple-design-system.sh`を実行する。
6. dark/lightの両themeでempty、loaded、rendered、errorを確認する。
7. `designs/reviews/pixel-forge-workbench--diagonal-pixel-border-icons-v2--dark.png`と`--light.png`を更新する。
8. `./scripts/ci-local.sh`を実行する。

`verify-apple-design-system.sh`はscreen層のstyle直書き、日英key不一致、font asset、両theme screenshot、shared component利用を検査し、違反時はCIを失敗させる。

同じ入力とwindow sizeで両themeを再撮影する場合は次を使う。app自身のcontent viewを取得するため、画面収録権限には依存しない。

```bash
./scripts/capture-apple-review.sh /absolute/path/to/input.jpg
```
