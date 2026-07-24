# 技術仕様と判断

## ✅ 決定

### Repository / core

- Rust Cargo workspace、Swift Package、iPhoneアプリ、サポートWebを同じrepositoryに置く。
- `pixel-core`を変換仕様の正本にする。
- `pixel-sprite`は`pixel-core`を利用して透過partの分割、frame合成、sprite sheet packingを行い、画像生成providerとfile I/Oを持たない。
- Swift連携にはUniFFI 0.32を使う。
- Apple向けRust成果物はstatic libraryをXCFrameworkに包む。
- core APIは同期処理とし、呼び出し側がbackground taskで実行する。
- v1のcore APIは`PixelSession::convert(RenderSettings)`とする。
- 課金、theme、ファイル永続化、画面状態を`pixel-core`と`pixel-ffi`へ持ち込まない。
- `pixel-cli`は個人利用とし、StoreKitによる課金制限を設けない。一般配布はMVPの対象外とする。
- Codexのrepo skillから標準`imagegen`を呼び出してparts sheetを作り、model APIや認証をRust CLIへ組み込まない。
- `apps/sprite-editor`はVite + Reactのローカル専用rig editorとし、公開用`apps/web`から分離する。
- sprite editorは生成済みpart PNGを画面上で合成して位置を即時確認するが、保存時の検証、減色、分割、frame合成、sheet packingは既存`pixel-cli sprite build`を正本とする。
- sprite manifest schema version 2はversion 1のinteger offsetを維持したまま、frameごとの`sizeDeltas`、`zIndexDeltas`とpartごとの`resizeAnchor`を追加する。version 1は読み取り互換とし、editorで開いた時点でversion 2へ正規化する。
- part resizeはpixel化後のopaque boundsだけをnearest-neighborで処理し、`resizeAnchor`のcanvas位置を固定する。小数scale、色補間、mesh変形を利用しない。
- sprite editorは`127.0.0.1`だけへbindし、起動引数のmanifest、source、outputをrepository内へ制限する。候補manifestの一時buildが成功した場合だけmanifestをatomicに置き換える。

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

### iPhone app

- UI targetはiOS 17以降のiPhoneだけとし、`TARGETED_DEVICE_FAMILY = 1`、Mac Catalyst無効、縦向きだけを宣言する。
- メインSceneは単一の`WindowGroup`とし、ホームから設定と変換をそれぞれfull-screen coverで表示する。設定には横方向の戻るgestureを持たせない。
- ホーム、変換モーダル、設定の3 surfaceでMVPを構成し、タブバーを設けない。
- 変換モーダルは`editing`、`rendering`、`result`、`failure`の状態を持つ。
- 変換はUI thread外で実行し、開始後200msを超えた場合だけ不定進捗を表示する。MVPでは複数変換を並列実行しない。
- 新規変換は成功時に新しい生成recordを作る。既存結果の調整では同じrecordのatomicな更新、または新しいrecordの作成を選べる。
- `調整する`はrecordのrecipeを正本として全パラメータを復元する。保存時と現行のalgorithm versionが不一致なら旧値を適用せず、警告とともに`PixelConversionSettings`の初期値へフォールバックする。
- editing上部には入力画像を置かず、設定へ追従する出力previewを固定する。内蔵変換スタイルと保存済み調整プリセットは小型の読込／保存操作から扱い、現在の調整名を同じ行へ表示する。元画像色、custom、33種類の組み込みpaletteは小型cardの横scroll railへ並べ、個別パラメータは折りたたみ式の`詳細調整`へ置く。詳細値が選択中presetと一致しなくなった場合は`カスタム調整`として扱う。
- editingの設定変更は短時間debounceしたpreview変換へ反映し、古いpreview結果で新しい設定を上書きしない。preview変換は直列化し、保存操作とは別にrecordを更新しない。
- editing下端には保存／更新を主操作、写真保存、画像共有、複製、削除をicon中心の操作railとして固定する。既存recordでは`別の画像として保存`も同時に提供し、新規recordでは複製と削除を表示しない。
- 調整プリセットは名前、`PixelConversionSettings`、algorithm version、作成日時、更新日時をApplication Supportへ保存する。同名保存は既存presetを更新し、適用時もalgorithm versionの互換性を確認する。
- 生成recordはrecipeに加えて内蔵スタイルIDまたは保存済みpreset UUIDを任意の参照として保持する。`調整する`では参照とrecipeの編集可能値が一致する場合に選択状態も復元し、参照がない旧recordは設定値の一致から内蔵／保存済みpresetを推定する。
- SwiftUIのthemeは`ForgePalette`を環境値として注入し、system、dark、lightで同一layout/component treeを使う。
- 無料版はsystem themeだけを選択でき、Proはdark/lightへ手動固定できる。
- UI fontはSIL Open Font License 1.1のDotGothic16をapp resourceとして同梱し、全対応言語で共通利用する。
- UI文言は日本語、英語、韓国語、繁体字中国語を持ち、設定画面のpixel selectorでsystemと各言語を切り替える。system時はiOSの最優先言語が対応言語ならその言語、それ以外なら英語へ解決する。
- ホームの生成結果cardは固定高とし、選択言語のlocaleで更新日時を表示する。tapでresult、長押しと振動で調整・写真保存・ライブラリ内への複製・削除のpixel action dialogを開く。
- 画像追加メニューは、利用可能な場合だけカメラ撮影を先頭に表示し、写真ライブラリ、Filesを続ける。撮影画像はJPEGへ正規化して既存の新規変換フローへ渡し、写真ライブラリへ自動保存しない。
- 画像追加メニュー、生成結果の操作dialog、削除確認、言語selectorはDesign層のpixel UI overlayを使い、Reduce Motionを尊重した表示アニメーションを持つ。
- 設定と変換はDesign層の共通modal scaffoldを使い、iPhoneの上部safe areaと共通paddingを常に確保する。
- iPhoneアプリは切り抜きUIを持たず、変換時のcropを常に画像全体へ設定する。coreと既存recipeのcrop互換性は維持する。
- 数値設定は直接入力、増減buttonの長押し、水平scrubのすべてに対応する。
- paletteはeditingの横scroll railへ名前、色数、小さな色swatchだけを表示し、選択をpreviewへ即時反映する。customの選択と編集では専用のfull-screen pickerを開く。
- 組み込みpaletteは`reference`、`tonal`、`balancedFamilies`を区別する。`reference`は色数を固定せず原典どおり、`tonal`は単一familyを4色以上、`balancedFamilies`は2〜3 familyを各4色以上かつ同数で構成する。
- reference paletteはGame Boy DMG 4階調、PICO-8公式16色、C64のPepto変換16色、IBM CGAのRGBI 16色、ZX Spectrumのbright blackを除く15色、Master Systemの2bit RGB全64色、Virtual Boyの黒と3段階の赤を収録する。Game Boy、C64、Virtual BoyのRGB値は実機の表示特性をsRGBへ近似した表現であり、hardware内部の固定sRGB値ではない。
- reference paletteの根拠は[Game Boy Pan Docs](https://gbdev.io/pandocs/Palettes.html)、[PICO-8 manual](https://www.lexaloffle.com/dl/docs/pico-8_manual.html)、[C64 VIC-II color analysis](https://www.pepto.de/projects/colorvic/2001/)、[IBM CGA RGBI palette](https://en.wikipedia.org/wiki/Color_Graphics_Adapter#Color_palette)、[ZX Spectrum manual](https://worldofspectrum.org/ZXBasicManual/zxmanchap16.html)、[Master System architecture](https://www.copetti.org/writings/consoles/master-system/)、[Virtual Boy four-level display](https://www.virtual-boy.com/forums/t/how-to-work-around-the-vbs-color-limitations/)とする。
- palette cardのswatchは全色を1〜4段へ自動配置し、64色paletteを含めて省略しない。
- custom paletteはSwiftUI標準`ColorPicker`（opacityなし）を色ごとに表示し、追加・編集・削除で構成する。カンマ区切りやhex列挙の文字入力は提供しない。
- paletteの適用方法と輪郭modeは文字だけのsegmented controlではなく、pixel preview付きの選択cardで示す。
- カメラ権限は撮影操作時に要求し、拒否または制限時はiOS設定への導線を提示する。
- 生成結果の外部保存はPNG画像だけを対象にし、Photosの追加専用権限を使って写真アプリへ保存する。recipeはローカルrecordの再生成用途に限る。
- 画面層は`Design/`のshared token/style/componentから組み立て、直接の色・font・control chrome指定をCIで拒否する。

`Developer` build configurationと`PixelForgeApp-Developer` schemeは`PIXEL_FORGE_DEVELOPER`を定義する。この構成だけ設定にFree / Pro切替を表示し、実際のStoreKit transactionを変更せずcapability判定を切り替える。

### Local persistence

- app sandbox内のApplication Supportへsource asset、生成PNG、recipe、metadataを保存する。
- `SourceAsset`はcontent hashをidentityとし、同じ入力の複数バリエーションで一つのsource byte列を共有する。
- `GeneratedImageRecord`はUUID、source hash、PNG path、recipe path、任意の変換preset参照、作成日時、更新日時、表示metadataを持つ。preset参照のないschema version 1 manifestも`nil`として読み込む。
- record複製時はPNG、recipe、metadata、preset参照を新しいUUIDへコピーし、source assetは既存hash参照を再利用する。
- record更新は一時出力へ変換した後、PNG、recipe、metadataを一つのcommitとして差し替える。失敗時は以前のrecordを変更しない。
- record削除後にsource参照数が0になった場合だけ、対応するsource assetを削除する。
- app内recordの削除は、写真アプリへ保存済みの画像へ影響させない。
- persistence schemaをversion管理し、migration前に参照中の画像ファイルを削除しない。

### StoreKit / Pro

- iPhoneアプリは無料配布とし、StoreKit 2のNon-Consumable商品を一つだけ提供する。
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
- 日本語と英語をstable pathで公開し、iPhoneアプリは選択中の言語に対応するURLを外部ブラウザで開く。

Cloudflareの現行構成は[Astro framework guide](https://developers.cloudflare.com/workers/framework-guides/web-apps/astro/)と[Static Site Generation](https://developers.cloudflare.com/workers/static-assets/routing/static-site-generation/)を実装時に再確認する。

## 🟡 暫定

- 入力上限は80 megapixel、targetは最大1024 x 1024、拡大後は最大16384 pixel/辺とする。
- XCFrameworkはarm64 iPhone実機、arm64 iPhone Simulator、macOS上のSwiftテスト用sliceを含める。
- 輪郭閾値は0から100の整数とし、OKLab距離へ線形変換する。
- 無料版の論理長辺は32、64、128px、拡大率は8倍とする。利用状況を確認した上で、無料範囲を狭めずに見直せる。

## ❓ 未決

- 正式な製品名、bundle identifier、App Store SKU
- Non-Consumableの商品identifier、価格、Family Sharing
- custom domain、GoogleフォームURL、運営者の法務表記
- iPadOS版の追加時期
- iPhoneアプリへのsprite asset workflow、透過背景除去、輪郭強調の追加
