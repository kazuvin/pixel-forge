# UIワークフロー

## 方向性

対象は写真をゲーム素材へ変換する個人制作者。画面の仕事は、入力と出力の差、出力寸法、recipeを一目で確認し、安全に書き出すこと。

## Visual system

- Canvas `#101417`: 画像比較の暗い作業面
- Panel `#182126`: recipe controls
- Ink `#F2F4EB`: 主要テキスト
- Muted `#8FA1A8`: metadata
- Forge `#FFB45B`: 実行と選択状態
- Grid `#2A373D`: pixel checker/grid
- 見出しはrounded system、寸法や値はmonospaced systemを使う。
- gradient、glass、装飾目的のshadowを使わない。

## Layout

```text
┌──────────────────────────────────────────┬───────────────┐
│ Pixel Forge                 [写真を選ぶ] │ レシピ        │
├────────────────────┬─────────────────────┤ size / colors │
│ INPUT              │ OUTPUT              │ dither / scale│
│                    │ pixel grid          │               │
│                    │                     │ [変換する]    │
└────────────────────┴─────────────────────┴───────────────┘
```

## 実装ルール

- tokenは`DesignTokens.swift`を正本にする。
- output imageは`.interpolation(.none)`で表示する。
- 空状態は次の操作を明示する。
- 変換中は重複実行を防ぐ。
- exportはPNGとrecipeを同時に保存する。
- UI変更後はmacOSで起動し、empty、loaded、rendered、errorを確認する。

