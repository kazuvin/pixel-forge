# 技術仕様と判断

## ✅ 決定

### Repository / core

- Rust Cargo workspace、Swift Package、macOSアプリ、サポートWebを同じrepositoryに置く。
- `pixel-core`を変換仕様の正本にする。
- Swift連携にはUniFFI 0.32を使う。
- Apple向けRust成果物はstatic libraryをXCFrameworkに包む。
- core APIは同期処理とし、呼び出し側がbackground taskで実行する。
- v1のcore APIは`PixelSession::convert(RenderSettings)`とする。
- 課金、theme、ファイル永続化、画面状態を`pixel-core`と`pixel-ffi`へ持ち込まない。
- `pixel-cli`は個人利用とし、StoreKitによる課金制限を設けない。一般配布はMVPの対象外とする。

既存のSwift/CLI adapterが利用する`PixelSession::render(PixelSettings)`は移行用の互換入口とし、v1変換仕様の正本には含めない。

### Conversion

- cropは元画像座標の矩形または画像全体で指定し、論理解像度の短辺はcropの縦横比から決定する。
- 透過入力は白へ合成し、v1の出力は常にopaque RGBAとする。
- 元画像色モードでは縮小後の色をそのまま利用する。
- paletteモードでは利用側が名前とRGB色列を渡し、coreはpaletteの永続化やゲーム固有presetを担当しない。
- paletteの近似色探索にはOKLab上の二乗距離を利用する。
- 色調保持ではpalette色の色相を基準に、HSLの彩度と明度を元画像側へ指定割合だけ補間する。無彩色paletteでは元画像の色相を利用する。
- 輪郭検出は縮小後の元画像色を参照し、右/下の隣接pixelとのOKLab色差が閾値を超えた境界の暗い側を1pixelだけmarkする。
- すべての輪郭色で2x2の輪郭maskを反復走査し、輪郭3pixelのL字角から頂点を落として斜めに接する2pixelへ整形する。直線と輪郭4pixelのsolid blockは維持する。
- なじむ輪郭色は変換後pixelの色相と彩度を保ち、明度を下げる。
- v1ではディザリングと入力画像からのpalette自動生成を行わない。
- recipe schemaとalgorithm versionはRust側が生成する。

### macOS app

- 最初のUI targetはmacOS 14以降とする。
- メインSceneは単一のホームウインドウとし、複数の編集ウインドウを提供しない。設定はSwiftUIの`Settings` Sceneで開く。
- ホーム、変換モーダル、設定の3 surfaceでMVPを構成し、タブバーを設けない。
- 変換モーダルは`editing`、`rendering`、`result`、`failure`の状態を持つ。
- 変換はUI thread外で実行し、開始後200msを超えた場合だけ不定進捗を表示する。MVPでは複数変換を並列実行しない。
- 新規変換は成功時に新しい生成recordを作る。既存結果の調整では同じrecordのatomicな更新、または新しいrecordの作成を選べる。
- SwiftUIのthemeは`ForgePalette`を環境値として注入し、system、dark、lightで同一layout/component treeを使う。
- 無料版はsystem themeだけを選択でき、Proはdark/lightへ手動固定できる。
- UI fontはSIL Open Font License 1.1のDotGothic16をapp resourceとして同梱し、日英で共通利用する。
- UI文言は日本語をdefault localization、英語を追加localizationとし、macOSの優先言語へ追従する。
- 画面層は`Design/`のshared token/style/componentから組み立て、直接の色・font・control chrome指定をCIで拒否する。

### Local persistence

- app sandbox内のApplication Supportへsource asset、生成PNG、recipe、metadataを保存する。
- `SourceAsset`はcontent hashをidentityとし、同じ入力の複数バリエーションで一つのsource byte列を共有する。
- `GeneratedImageRecord`はUUID、source hash、PNG path、recipe path、作成日時、更新日時、表示metadataを持つ。
- record更新は一時出力へ変換した後、PNG、recipe、metadataを一つのcommitとして差し替える。失敗時は以前のrecordを変更しない。
- record削除後にsource参照数が0になった場合だけ、対応するsource assetを削除する。
- app内recordの削除は、save panelで外部へ書き出したファイルへ影響させない。
- persistence schemaをversion管理し、migration前に参照中の画像ファイルを削除しない。

### StoreKit / Pro

- macOSアプリは無料配布とし、StoreKit 2のNon-Consumable商品を一つだけ提供する。
- Pro entitlementはSwift側の単一serviceで管理し、画面へ生のStoreKit transactionを露出しない。
- 機能判定は`ProFeature`のようなcapability単位へ集約し、画面ごとのboolean判定を増やさない。
- 購入済み判定はStoreKitが検証したcurrent entitlementを正本とし、transaction updateをアプリ起動中に監視する。
- unverified transactionでProを解放しない。
- 返金またはrevocation後も既存recordの閲覧、通常の書き出し、削除を許可する。Pro設定による新規変換と再変換だけを拒否する。
- `pixel-core`、`pixel-ffi`、`PixelCoreKit`、`pixel-cli`はPro entitlementを参照しない。

### Support web

- `apps/web`はAstroのstatic outputを利用する。
- privacy、terms、support、404はbuild時にHTMLへprerenderする。
- Cloudflare Workers Static Assetsの`assets.directory`を`./dist`に設定し、`not_found_handling`は`404-page`とする。
- static siteにはWorker entry point、Astro Cloudflare adapter、SSR、database bindingを追加しない。
- 日本語と英語をstable pathで公開し、macOSアプリは現在の言語に対応するURLを外部ブラウザで開く。

Cloudflareの現行構成は[Astro framework guide](https://developers.cloudflare.com/workers/framework-guides/web-apps/astro/)と[Static Site Generation](https://developers.cloudflare.com/workers/static-assets/routing/static-site-generation/)を実装時に再確認する。

## 🟡 暫定

- 入力上限は80 megapixel、targetは最大1024 x 1024、拡大後は最大16384 pixel/辺とする。
- XCFrameworkは開発マシン向けarm64 macOS sliceから開始する。
- 輪郭閾値は0から100の整数とし、OKLab距離へ線形変換する。
- 無料版の論理長辺は32、64、128px、拡大率は8倍とする。利用状況を確認した上で、無料範囲を狭めずに見直せる。

## ❓ 未決

- 正式な製品名、bundle identifier、App Store SKU
- Non-Consumableの商品identifier、価格、Family Sharing
- custom domain、GoogleフォームURL、運営者の法務表記
- 組み込みpalette presetの標準セット
- iPadOS版の追加時期
- sprite sheet、透過背景除去、輪郭強調の追加
