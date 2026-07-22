# AGENTS.md

このリポジトリで作業するAI開発エージェント向けの共有ルール。

## 作業前に読む

- `docs/requirements.md`
- `docs/spec.md`
- UI変更では `docs/ui-workflow.md`

## 境界

- `pixel-core`を画像変換仕様の正本とし、Swift、AppKit、UniFFI、CLIの都合を持ち込まない。
- `pixel-ffi`は型変換だけを担当し、画像処理を実装しない。
- `pixel-cli`とSwiftアプリは同じ`pixel-core`を利用する。
- ゲーム固有の命名、配置、Unity設定はcoreではなくpresetまたは利用側へ置く。
- MVPはローカル処理だけで成立させる。アカウント、クラウド同期、生成AI、バックエンドは追加しない。

## 開発

- 変換アルゴリズムとrecipe互換性はRed -> Green -> Refactorで進める。
- コードはHow、テストはWhat、commit logはWhy、コメントはWhy notを示す。
- 同じ入力、設定、algorithm versionから同じRGBA出力を得られる決定性を守る。
- 生成されたSwift bindingとXCFrameworkを直接編集しない。`scripts/build-apple.sh`で再生成する。
- UIはshared tokenを利用し、出力画像には補間をかけない。
- UI画面は`apps/apple/PixelForgeApp/Sources/PixelForgeApp/Design/`のtoken、style、componentだけを組み合わせる。画面側へ色、font、button chrome、surface shapeを直書きしない。
- 必要なUI部品はまず既存の`Forge*` componentで表現できるか確認し、再利用可能な見た目は`Screens/`ではなく`Design/`へ追加する。
- theme固有値は`ForgePalette.dark`と`ForgePalette.light`だけに置き、画面やcomponentでtheme分岐しない。
- UI iconは`ForgeIcon`と`ForgeIconName`へpixel gridとして定義し、SF Symbolsを画面・共通componentから直接利用しない。
- 表示文言は日英`Localizable.strings`へ同じkeyで追加し、UI fontは同梱のDotGothic16を`ForgeTypography`経由で使う。
- `Design/`または`Screens/`を変更したら、iPhone縦向きの黒基調・白基調で起動確認し、`designs/reviews/pixel-forge-{home,conversion-editing,conversion-result,settings}--{dark,light}.png`を更新する。
- `scripts/verify-apple-design-system.sh`は上記の直書き、翻訳key差分、font、review screenshotを検査する。回避する変更は行わない。
- 完了前に`./scripts/ci-local.sh`を実行する。
- 既存の未コミット変更はユーザーの作業として扱い、勝手に戻さない。

## Git

初期Git設定は意図的に未実施。ユーザーが準備するときは`docs/git-setup.md`に従う。
