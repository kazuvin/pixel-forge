# 要求定義

## プロダクト

Pixel Forgeは、写真を機械的かつ再現可能なピクセルアートへ変換するローカルツールである。iPhone SwiftUIアプリでは画像の読み込み、調整、比較、履歴管理、共有を一つの制作フローとして提供し、同じRustエンジンを個人利用のCLIからも利用する。

対象は、写真からゲーム素材を繰り返し作る個人制作者である。アカウントやクラウドを前提にせず、入力画像と生成画像はiPhoneのアプリ管理領域だけで扱う。

## iPhoneアプリMVP

- 対応端末はiPhoneだけとし、iPadとMac Catalystを対象外にする。
- 画面方向は縦向きだけとする。

### 画面と導線

- メイン画面はホームだけとし、タブバーを設けない。
- 表示・言語設定、購入、サポート、アプリ情報はホームから遷移するアプリ内設定画面へまとめる。
- ホームではカメラで新しく撮影するか、写真ライブラリまたはFilesから画像を選べる。「アップロード」ではなく「カメラで撮る」「写真を選ぶ」「ファイルから選ぶ」と表現する。
- カメラ撮影後は、その画像を入力した共通の変換モーダルを設定状態で開く。撮影画像を写真ライブラリへ自動保存しない。
- カメラ権限が未決定なら操作時に要求し、拒否または制限されている場合はiPhoneの設定を開ける案内を表示する。カメラを利用できない環境では撮影項目を表示しない。
- ホームには生成画像を新しい順で常に2列に並べる。
- ホームのカード位置は変換完了や上書きによって移動させない。
- 生成画像カードを選ぶと、共通の変換モーダルを結果表示状態で開く。
- 生成画像カードは文字量にかかわらず同じ高さを保ち、更新日時は選択中の言語と地域に合わせて表示する。
- 生成画像カードを長押しすると振動後にpixel UIの操作ダイアログを開き、調整、写真への保存、ライブラリ内への複製、削除を選べる。削除は続けて確認ダイアログを表示する。

### 共通の変換モーダル

- 新規変換、既存結果の表示、設定調整を同じモーダルで扱う。
- 新規変換は`設定 -> 変換中 -> 結果`の順に状態遷移する。
- 変換はUIを停止させないbackground taskで実行するが、MVPでは複数変換の並列queueを設けない。
- 変換が200ms以内に完了した場合はloadingを表示せず、直接結果へ切り替える。200msを超えた場合だけモーダル内へ不定進捗を表示し、見せるための待ち時間は追加しない。
- 変換中は同じ操作の重複実行を防ぐ。
- 結果では入力と出力、論理寸法、保存寸法、palette、algorithm versionを確認できる。
- 既存結果を調整した場合は`この画像を更新`と`別の画像として保存`を選べる。
- 変換設定は内蔵スタイルまたは保存済みプリセットの選択を最初に提示し、数値、palette、輪郭などの個別パラメータは`詳細調整`を開いた場合だけ表示する。
- 既存結果の`調整する`では保存済みrecipeから全調整値と選択した内蔵スタイルまたは保存済みプリセットを復元する。recipeのalgorithm versionが現行版と異なる場合は警告を表示し、調整値と選択状態を初期値へ戻す。
- 現在の調整値は名前付きプリセットとして端末内へ保存し、他の画像の調整へ適用、同名更新、削除できる。
- 上書きは変換成功後にPNG、recipe、metadataをまとめて置き換え、失敗時は以前の結果を維持する。
- 別の画像として保存した場合は、以前の結果を維持したまま新しいカードを追加する。

### 変換

- カメラで撮影したJPEG、写真ライブラリのPNG/JPEG、FilesのPNG/JPEG/PPMを読み込める。
- iPhoneアプリでは元画像全体を変換対象とし、切り抜きUIを設けない。
- 論理解像度は元画像の長辺で指定し、短辺は縦横比から決定する。
- 元画像色、または明示的な組み込み/カスタムpaletteを利用できる。
- 組み込みpaletteは33種類を用意する。実機・既存規格の再現paletteは原典の色数と色順を優先し、単色系は4色以上、創作系は2〜3系統を各4色以上かつ同数で構成する。一方の色系統だけが近似色探索で優先されないことを守りつつ、全paletteを同じ色数へ揃えない。
- 組み込みpaletteはeditingの横scroll railと専用の選択画面へcardで表示し、各cardに使用色を省スペースで示す。
- カスタムpaletteの色は文字列へ列挙せず、iOS標準のカラーピッカーで1色ずつ追加、編集、削除できる。
- paletteは厳密適用と、彩度/明度を割合指定で残す適用を選べる。
- 輪郭線なし、黒、周辺色になじむ暗色を選び、検出閾値を調整できる。
- 縮小、色変換、輪郭検出、nearest-neighbor整数倍拡大をRustで処理する。既存recipeとCLIの互換性のためcoreのcrop設定は維持する。
- 同じ入力、設定、algorithm versionから同じRGBA結果を生成できる。
- 出力previewにはpixel interpolationを適用しない。

### ローカルライブラリと書き出し

- 生成画像はアプリ再起動後もホームに残る。
- 元画像は入力hash単位でアプリ管理領域へ保存し、同じ元画像から作る複数の生成結果で共有する。
- 生成結果ごとにPNG、recipe、source参照、選択した内蔵スタイルまたは保存済みプリセットの参照、作成日時、更新日時、表示用metadataを保持する。
- 生成結果の複製はPNG、recipe、preset参照を新しいrecordへ引き継ぎ、同じ元画像はhash単位で共有する。
- 生成結果を削除しても、ユーザーが外部へ書き出したファイルは削除しない。
- 元画像を参照する最後の生成結果が削除された場合は、アプリ管理領域の元画像も削除する。
- 生成結果はPNG画像だけを写真アプリへ保存できる。再生成用recipeはアプリ内の生成結果に保持し、外部へ書き出さない。
- 写真アプリへの保存はユーザー操作時だけ追加専用権限を要求し、成功と失敗を変換結果内へ表示する。

## 買い切りPro

- iPhoneアプリは無料で配布し、StoreKit 2のNon-Consumable商品`Pixel Forge Pro`を一度購入するとPro機能を解放する。
- 広告、サブスクリプション、変換回数課金を導入しない。
- 購入のためのPixel Forge独自アカウントやbackendを設けない。
- 課金判定はSwiftアプリだけが担当し、`pixel-core`、`pixel-ffi`、個人利用のCLIへ持ち込まない。
- 無料版でも画像の読み込み、基本変換、preview、PNG画像の写真アプリ保存、無制限のローカル履歴を利用できる。

### 無料版

- 元画像色
- 論理長辺32、64、128px
- 8倍のnearest-neighbor拡大
- 輪郭なし
- iOSの外観へ自動追従するtheme

### Pro

- 対応範囲内での任意の論理長辺
- 対応範囲内での任意の整数拡大率
- 組み込みpaletteとカスタムpalette
- paletteの厳密適用と色調保持
- 黒または周辺色になじむ輪郭と検出閾値
- 黒基調または白基調themeの手動固定
- 現行版で提供する高度な変換オプション

### 購入権利

- 未購入、取得中、保留、購入済み、失敗、復元、返金または失効を区別して表示する。
- Pro機能は隠さずlock付きで表示し、選択した時だけ買い切り内容を説明する。起動時や画像読み込み時に購入画面を自動表示しない。
- 購入完了後は操作中の設定を失わず、その場でPro機能を利用可能にする。
- 返金または権利失効後も既存の生成画像を閲覧、書き出し、削除できる。Pro設定による新規変換と再変換だけを制限する。
- Pro権利がない状態ではthemeをiOSの外観への自動追従へ戻す。

## 設定とサポート

アプリ内設定画面は次のセクションを持つ。

- 言語: システムデフォルト、English、日本語、한국어、繁體中文（台灣）
- 表示: iOSに合わせる、黒基調、白基調
- Pixel Forge Pro: 購入状態、買い切り商品の説明、購入、購入の復元
- サポート: App Storeでレビュー、アプリをシェア、ご意見・ご要望、プライバシーポリシー、利用規約
- 情報: marketing versionとbuild number

開発者向けの専用ビルド構成では、StoreKitの購入状態へ影響させずにFree / Proを切り替えるスイッチを設定へ追加する。通常のDebug / Releaseビルドには表示しない。

レビューとシェアは公開済みのApp Store URLを利用する。ご意見・ご要望は外部ブラウザでGoogleフォームを開く。プライバシーポリシー、利用規約、サポートページは日英で公開し、日本語選択時は日本語、それ以外は英語の安定したURLを開く。

言語のデフォルトはシステムデフォルトとする。iOSの最優先言語が日本語、英語、韓国語、繁体字中国語なら対応する言語を使い、それ以外の言語では英語へフォールバックする。選択は再起動後も保持し、変更時は表示文言とサポートURLへ即時反映する。

## サポートWeb

- monorepoの`apps/web`にAstroの静的サイトを置く。
- 日本語と英語のsupport、privacy、terms、404を静的生成する。
- Cloudflare Workers Static Assetsで`dist`を配信し、SSR、Worker script、database、accountを追加しない。
- 公開ページへ広告、analytics、cookie bannerを追加しない。データを収集する機能を追加した場合はprivacy文書とApp Store申告を同時に更新する。
- Googleフォームは外部サービスであることと、フォームで収集する情報をprivacy文書へ記載する。

詳細は`docs/web-spec.md`を正本とする。

## 個人向けSprite Asset CLI

- Codexの`imagegen`で作った正方形のparts sheetを、個人利用のCLIからgame用sprite assetへ変換できる。
- 画像生成はCodex skillが担当し、model API、認証、prompt実行をRust workspaceとiPhoneアプリへ持ち込まない。
- parts sheetは見えない固定gridの各cellへbody、head、arm、leg、equipmentなどを分離して配置する。part名と個数は固定せず、monster固有の構成をmanifestへ記録する。
- parts sheet全体を一度だけ共通の論理解像度とpaletteへ変換してからpartへ分割し、part単位の色ぶれを避ける。
- 透過partをinteger pixel offsetと明示z-orderで合成し、1frame 64x64、8frame、8fpsのidle animationを横一列のPNGへ出力する。z-orderは全frame共通値に加えてframeごとの差分を指定できる。
- head、body、armの沈みはmanifestのframe配列で定義し、legは接地を守る標準presetを用意する。editorには静止、呼吸、重量級、小刻み、浮遊のcharacter motion presetを用意し、適用後もframeごとの値を編集できる。
- partはframeごとにopaque boundsの幅と高さをinteger pixel差分で変更できる。resizeは明示した固定点を維持するnearest-neighborとし、色補間を行わない。
- game用の論理sprite sheet、nearest-neighbor拡大preview、frame metadata、各part PNG、入力hashとalgorithm versionを持つrecipeを出力する。
- 同じ透過parts sheetとmanifestから同じdecode後RGBA、metadata、recipeを生成する。
- 生成済みpartの基準位置、接続点、全体およびframeごとのz-order、frameごとのoffsetと幅・高さ差分を調整するローカル専用editorを提供する。
- editorはpartのドラッグ、矢印キーによる1pixel移動、8frameの選択と再生、任意の完成参考画像のoverlay、manifestの書き出しを提供する。
- editorの保存は候補manifestを一時出力でCLI buildしてから元のmanifestへ反映し、game用assetも同じ`pixel-cli sprite build`で再生成する。
- editorのlocal serverは`127.0.0.1`だけへbindし、起動時に指定したrepository内path以外を読み書きしない。公開Webへ含めず、deployしない。
- Unityなどのgame engine固有importerは持たない。

詳細は`docs/sprite-workflow.md`を正本とする。

## MVPに含めない

- iPhoneアプリ内の生成AIによる描き直し
- iPhoneアプリ内の手描き編集、レイヤー、アニメーション
- クラウド保存、アプリ独自アカウント、端末間の画像同期
- 広告、サブスクリプション、消費型課金
- 複数変換の並列実行またはbatch queue
- Unity/ゲームエンジン固有importer
- iPadOS、macOS、Mac Catalyst、Windows、Android向けUI
- ICC profileを使った厳密な印刷色管理
- iPhone静止画変換での透過背景の維持または背景除去
- ディザリング
- 入力画像からのpalette自動生成

## 品質

- coreはSwift、StoreKit、Apple SDKなしでテストできる。
- FFI境界でpanicを外へ漏らさない。
- recipeにschema version、algorithm version、入力hash、全設定、palette、論理/保存寸法を含める。
- 古いrecipeと生成画像はアプリ更新後も表示でき、algorithm更新だけを理由に自動再変換しない。
- 上書き、削除、schema migrationの失敗で既存の生成ファイルを失わない。
- 無料/Pro、購入状態、日英韓繁中、system/dark/light、empty/result/errorを自動テストとreview screenshotの対象にする。
