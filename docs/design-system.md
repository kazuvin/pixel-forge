# Pixel Forge Design System

Pixel ForgeのSwiftUI design systemは、pixel-art変換作業を行う「機材の操作盤」を表現する。参考画像のコピーではなく、対角pixelの細枠、状態lamp、pixel grid icon、data labelという構造を写真変換workbenchへ移植する。

## Source of truth

- Theme/color/spacing/size: `Design/ForgeDesignTokens.swift`
- Font/type scale: `Design/ForgeTypography.swift`
- Pixel icon set: `Design/ForgeIcons.swift`
- Shared style/components: `Design/ForgeComponents.swift`
- Japanese/English copy: `Resources/{ja,en}.lproj/Localizable.strings`
- Screen composition: `Screens/*.swift`

## Theme contract

`ForgeTheme.dark`と`ForgeTheme.light`はそれぞれ`ForgePalette`だけを切り替える。`ForgeTheme.system`は現在のmacOS appearanceを参照してdark/lightいずれかのpaletteへ解決し、第三のpaletteを持たない。component側は`@Environment(\.forgePalette)`からsemantic colorを読み、theme名や購入状態でstyleを条件分岐してはならない。

新しい色が必要な場合は、用途を表すsemantic tokenとしてdark/light両方へ同時追加する。画面固有のhex値や`Color`は追加しない。

## Component contract

- Primitive: `ForgePixelChamferShape`, `ForgePixelBorder`, `ForgeIcon`, `ForgeDivider`, button chrome, text style
- Container: `ForgeCanvas`, `ForgePixelSurface`, `ForgeSidebar`
- Control: `ForgeButton`, `ForgeIconButton`, `ForgeMetricStepper`, `ForgeSegmentedControl`
- Information: `ForgeSectionHeader`, `ForgeAlertBanner`, `ForgeStatusStrip`
- Workbench: `ForgeTopBar`, `ForgePreviewPane`, `ForgeEmptyState`
- Settings: `ForgeThemeCard`, `ForgeTypographySample`

Screenはこれらを組み合わせ、再利用されるchromeをprivate viewとして複製しない。新規componentはtheme環境、keyboard/disabled state、accessibility label、日英の文字長を考慮する。

ホーム、共通変換モーダル、設定の新しいcomponentは`docs/ui/layouts/mvp-macos-screens.md`の実画面から導出する。Pro lock、生成画像card、drop target、modal statusのように複数箇所で使う見た目は`Design/`へ置き、画面固有のprivate styleとして複製しない。

surfaceの面は45度のchamferで切り、斜めのborderは1セルごとに角だけが接するsquare pixel列で描く。斜線をL字のrect連続で描かず、通常のrounded strokeにも戻さない。iconの斜線にも同じ1セル対角ルールを使い、`ForgeIconName`の16×16 gridへ追加する。画面やcomponentからSF Symbolsを直接呼ばない。

## Review contract

DesignまたはScreenのSwiftを変更した差分には、dark/light両方のworkbench screenshotを含める。出力previewは実画像を使い、補間なしであることを目視確認する。

```bash
./scripts/capture-apple-review.sh /absolute/path/to/input.jpg
./scripts/verify-apple-design-system.sh
./scripts/ci-local.sh
```

検査を通すためにscreen名やfile配置を偽装せず、共通化できない理由がある場合は先にこのcontractを更新する。
