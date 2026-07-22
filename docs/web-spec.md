# サポートWeb仕様

## 目的

Pixel ForgeのApp Store審査と利用者サポートに必要な公開情報を、安定したURLで日本語と英語へ提供する。画像変換、購入判定、ユーザーaccountはWebへ持ち込まない。

## Technology

- monorepoの`apps/web`にAstroを置く。
- Astroのdefault static outputで全ページをbuild時にHTMLへ生成する。
- `@astrojs/cloudflare` adapter、SSR、API route、database、Worker entry pointを追加しない。
- Cloudflare Workers Static Assetsへ`dist`をdeployする。
- `not_found_handling`は`404-page`、`html_handling`は`auto-trailing-slash`とする。

想定する`wrangler.jsonc`は次のとおり。`compatibility_date`は実装開始日に更新する。

```jsonc
{
  "$schema": "./node_modules/wrangler/config-schema.json",
  "name": "pixel-forge-web",
  "compatibility_date": "2026-07-22",
  "assets": {
    "directory": "./dist",
    "not_found_handling": "404-page",
    "html_handling": "auto-trailing-slash"
  }
}
```

Cloudflareの設定は実装時に[Astro framework guide](https://developers.cloudflare.com/workers/framework-guides/web-apps/astro/)と[Static Site Generation](https://developers.cloudflare.com/workers/static-assets/routing/static-site-generation/)を再確認する。

## Pages / URLs

custom domainは未決とし、次のstable pathを契約とする。

```text
/ja/support/
/ja/privacy/
/ja/terms/
/en/support/
/en/privacy/
/en/terms/
/404.html
```

- `/`はbrowser languageを参考に日英の入口を示す。JavaScriptだけに依存したredirectは行わない。
- headerまたはfooterに言語切替を常設する。
- iPhoneアプリは設定中の表示言語に対応するURLを直接開く。
- 公開後はpathを変更せず、変更が必要な場合は恒久redirectを用意する。

## Support

support pageは次を含む。

- Pixel Forgeの対応OSとlocal conversionであること
- よくある問題への短い案内
- Googleフォームの`ご意見・ご要望を送る`リンク
- privacyとtermsへのリンク
- 現在のapp versionを確認する方法
- App Store product pageへのリンク

Googleフォームは新しいtabで開き、Googleが提供する外部サービスへ移動することをリンク付近に表示する。フォームで収集する項目は目的に必要な範囲へ限定し、privacy文書と一致させる。

## Privacy

privacy pageは少なくとも次を明記する。

- 入力画像、生成画像、recipeはlocalで処理、保存され、Pixel Forgeのserverへ送信されないこと
- カメラは利用者が撮影を選んだ時だけ使用し、撮影画像を写真ライブラリへ自動保存しないこと
- StoreKitによる購入処理をAppleが扱うこと
- アプリとWebが直接収集するdataの有無
- Googleフォームで利用者が任意送信する情報、その目的、送信先
- 第三者service、保持、削除依頼、問い合わせ方法
- 制定日と最終更新日

analytics、広告、cookie、追加のthird-party SDKを導入した場合は、公開文書とApp Store Connectのprivacy回答を同じreleaseで更新する。

## Terms

terms pageは少なくとも次を扱う。

- 提供主体、適用範囲、制定日、更新日
- 入力画像を利用する権利と責任
- 入力画像と生成物の権利が利用者に残ること
- 生成結果、特定用途適合性、損害に関する扱い
- Pixel Forge Proが買い切りであり、購入と返金をApp Storeの仕組みで扱うこと
- 禁止事項、提供変更、終了、準拠法、問い合わせ方法

独自termsの公開前に、AppleのStandard EULAとの関係を確認し、必要に応じて法律の専門家によるreviewを受ける。

## Design / accessibility

- iPhoneアプリと同じPixel Forgeのbrand、DotGothic16、日英の語彙を使う。
- appの操作盤をそのままWebへ複製せず、長文を読みやすい幅、行間、heading hierarchyを優先する。
- accent、対角pixel border、pixel grid iconのうち一つだけを署名要素として使い、法務文書の可読性を損なう装飾を追加しない。
- keyboard操作、visible focus、semantic heading、landmark、WCAG相当のcontrast、Reduce Motionを満たす。

## Privacy / security baseline

- 広告、analytics、tracking pixel、cookie bannerを追加しない。
- 外部scriptを読み込まず、Googleフォームは通常の外部linkにする。
- productionではHTTPSのcustom domainを使用する。
- CSP、`Referrer-Policy`、`X-Content-Type-Options`をstatic asset headersで設定する。
- source map、repository用Markdown、開発fileをstatic assetsへ含めない。

## Verification / deployment

- 日英ページに同じ必須sectionがあることを検査する。
- internal link、App Store URL、GoogleフォームURLのlink checkを行う。
- `astro check`、`astro build`、local previewを通す。
- `wrangler deploy`前に`dist`だけがasset対象であることを確認する。
- production deploy後に全stable URL、404、HTTPS、mobile layoutをsmoke testする。
