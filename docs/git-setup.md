# Git初期設定手順

このディレクトリは基盤作成時点ではGit repositoryではない。GitHub側にREADMEや`.gitignore`を追加しない空repositoryを作ってから、以下を実行する。

## 1. ローカルrepositoryを初期化

```bash
cd ~/Develop/pixel-forge
git init -b main
git status --short --branch
```

## 2. 品質ゲート

```bash
./scripts/ci-local.sh
```

## 3. 最初のcommit

```bash
git add .
git diff --cached --check
git commit -m "feat: initialize pixel art workspace"
```

## 4. GitHub remoteを登録してpush

`<owner>`と`<repository>`を実際の値へ置き換える。

```bash
git remote add origin git@github.com:<owner>/<repository>.git
git remote -v
git push -u origin main
```

## 5. 初回push後の確認

```bash
git status --short --branch
git log -1 --oneline
```

## 注意

- 公開repositoryにする前にlicenseを決める。
- `target/`、`.build/`、生成XCFrameworkはcommitしない。
- `Cargo.lock`はアプリケーションworkspaceの再現性のためcommitする。
- bundle identifierと署名設定は、配布を始める段階でXcode application targetとともに決める。

