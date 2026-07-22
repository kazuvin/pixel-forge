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
- 完了前に`./scripts/ci-local.sh`を実行する。
- 既存の未コミット変更はユーザーの作業として扱い、勝手に戻さない。

## Git

初期Git設定は意図的に未実施。ユーザーが準備するときは`docs/git-setup.md`に従う。

