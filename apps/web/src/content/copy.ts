export type Locale = "ja" | "en";

export interface Section {
  heading: string;
  paragraphs: string[];
  items?: string[];
}

export interface LegalDocument {
  title: string;
  eyebrow: string;
  summary: string;
  updated: string;
  sections: Section[];
}

const updatedJa = "制定・最終更新: 2026年7月22日";
const updatedEn = "Effective and last updated: July 22, 2026";

export const copy = {
  ja: {
    languageName: "日本語",
    nav: { support: "サポート", privacy: "プライバシー", terms: "利用規約" },
    support: {
      title: "サポート",
      eyebrow: "PIXEL FORGE / HELP",
      summary: "Pixel ForgeはmacOS 14以降で動作する、ローカル完結の画像変換アプリです。写真や生成画像をPixel Forgeのサーバーへ送信しません。",
      feedback: "ご意見・ご要望を送る",
      feedbackNote: "Google Formsが提供する外部ページへ移動します。フォームが未設定の場合は公開準備中と表示されます。",
      appStore: "App StoreでPixel Forgeを見る",
      appStoreNote: "App Store公開URLはリリース時に設定されます。",
      sections: [
        {
          heading: "画像を読み込めない場合",
          paragraphs: ["PNG、JPEG、PPM形式を利用できます。ファイルが破損していないか、別のアプリで開けるかを確認してください。"],
        },
        {
          heading: "変換や書き出しが失敗する場合",
          paragraphs: ["出力サイズを小さくし、書き出し先の空き容量とアクセス権を確認してください。上書き変換に失敗しても以前の生成画像は維持されます。"],
        },
        {
          heading: "購入を復元する",
          paragraphs: ["設定の「Pixel Forge Pro」から「購入を復元」を選びます。購入と返金はAppleのApp Storeの仕組みで処理されます。"],
        },
        {
          heading: "バージョンを確認する",
          paragraphs: ["アプリの設定を開き、「情報」に表示されるバージョンとビルド番号をご確認ください。お問い合わせ時に添えると調査がスムーズです。"],
        },
      ] satisfies Section[],
    },
    privacy: {
      title: "プライバシーポリシー",
      eyebrow: "PIXEL FORGE / PRIVACY",
      summary: "Pixel Forgeは、画像変換をローカルで行い、必要以上の情報を収集しない方針で設計されています。",
      updated: updatedJa,
      sections: [
        {
          heading: "1. アプリ内の画像とレシピ",
          paragraphs: ["入力画像、生成画像、再生成用recipeは利用者のMac内で処理・保存されます。Pixel Forgeが運営するサーバーへ送信されません。"],
        },
        {
          heading: "2. 購入情報",
          paragraphs: ["Pixel Forge Proの購入、復元、返金および購入状態の確認はAppleのStoreKitとApp Storeが処理します。Pixel Forgeは決済カード情報を取得しません。"],
        },
        {
          heading: "3. アプリとWebによる直接収集",
          paragraphs: ["現行のアプリとWebサイトには、独自アカウント、広告、アクセス解析、トラッキングpixel、Cookieを使う機能はありません。"],
        },
        {
          heading: "4. Google Formsで任意送信する情報",
          paragraphs: ["ご意見・ご要望フォームはGoogle Formsを利用します。利用者が任意で入力した問い合わせ内容、返信先、アプリのバージョン等は、回答と品質改善のためGoogleへ送信されます。画像や機密情報を送らないでください。"],
        },
        {
          heading: "5. 保持、削除、問い合わせ",
          paragraphs: ["フォーム回答は対応に必要な期間だけ保持します。削除依頼や本ポリシーへの問い合わせはサポートページのフォームから行えます。Google側の処理にはGoogleのポリシーが適用されます。"],
        },
        {
          heading: "6. 変更",
          paragraphs: ["収集機能や第三者SDKを追加する場合は、本ポリシーとApp Storeのプライバシー申告を同じリリースで更新します。"],
        },
      ] satisfies Section[],
    } satisfies LegalDocument,
    terms: {
      title: "利用規約",
      eyebrow: "PIXEL FORGE / TERMS",
      summary: "本規約は、Pixel Forgeアプリおよび関連サポートサイトの利用条件を定めます。",
      updated: updatedJa,
      sections: [
        {
          heading: "1. 提供主体と適用範囲",
          paragraphs: ["Pixel Forgeの提供者（正式な事業者表記はApp Store公開前に確定します）が、本アプリとサポートサイトを提供します。本規約はこれらの利用に適用され、AppleのStandard EULAと矛盾する場合は適用される条件を優先します。"],
        },
        {
          heading: "2. 入力画像と生成物",
          paragraphs: ["利用者は、入力画像を利用・変換するために必要な権利を有するものとします。入力画像と生成物の権利は、第三者の権利を除き利用者に残ります。"],
        },
        {
          heading: "3. 生成結果と免責",
          paragraphs: ["生成結果の正確性、完全性、特定用途への適合性は保証されません。法令で認められる範囲で、利用または利用不能から生じる間接的な損害について責任を負いません。"],
        },
        {
          heading: "4. Pixel Forge Pro",
          paragraphs: ["Pixel Forge ProはApp Storeで提供する買い切りのNon-Consumable商品です。購入、復元、返金はAppleの仕組みと規約に従います。サブスクリプションではありません。"],
        },
        {
          heading: "5. 禁止事項",
          paragraphs: ["法令や第三者の権利を侵害する利用、アプリや配信基盤への妨害、不正な購入状態の作成、セキュリティ機構の回避を禁止します。"],
        },
        {
          heading: "6. 変更、終了、準拠法",
          paragraphs: ["機能や提供を変更・終了する場合があります。本規約は日本法を準拠法とし、強行法規により利用者へ認められる権利を制限しません。問い合わせはサポートページから受け付けます。"],
        },
      ] satisfies Section[],
    } satisfies LegalDocument,
  },
  en: {
    languageName: "English",
    nav: { support: "Support", privacy: "Privacy", terms: "Terms" },
    support: {
      title: "Support",
      eyebrow: "PIXEL FORGE / HELP",
      summary: "Pixel Forge is a local image conversion app for macOS 14 and later. It does not upload your source or generated images to a Pixel Forge server.",
      feedback: "Send feedback or a request",
      feedbackNote: "This opens an external page provided by Google Forms. Until the form URL is configured, it is shown as unavailable.",
      appStore: "View Pixel Forge on the App Store",
      appStoreNote: "The public App Store URL will be configured at release.",
      sections: [
        {
          heading: "If an image will not open",
          paragraphs: ["Pixel Forge accepts PNG, JPEG, and PPM files. Check that the file is intact and opens in another application."],
        },
        {
          heading: "If conversion or export fails",
          paragraphs: ["Try a smaller output size, then check free disk space and permission for the export location. A failed overwrite leaves the previous generated image unchanged."],
        },
        {
          heading: "Restore a purchase",
          paragraphs: ["Open Settings, find Pixel Forge Pro, and choose Restore Purchase. Apple processes purchases and refunds through the App Store."],
        },
        {
          heading: "Find the app version",
          paragraphs: ["Open the app's Settings and find the version and build number under About. Include both when asking for help."],
        },
      ] satisfies Section[],
    },
    privacy: {
      title: "Privacy Policy",
      eyebrow: "PIXEL FORGE / PRIVACY",
      summary: "Pixel Forge is designed to convert images locally and avoid collecting information it does not need.",
      updated: updatedEn,
      sections: [
        {
          heading: "1. Images and recipes in the app",
          paragraphs: ["Source images, generated images, and reproducible recipes are processed and stored locally on your Mac. They are not sent to a server operated by Pixel Forge."],
        },
        {
          heading: "2. Purchase information",
          paragraphs: ["Apple handles Pixel Forge Pro purchases, restoration, refunds, and entitlement status through StoreKit and the App Store. Pixel Forge does not receive payment card details."],
        },
        {
          heading: "3. Information collected directly by the app and website",
          paragraphs: ["The current app and website do not provide a Pixel Forge account and do not use ads, analytics, tracking pixels, or cookies."],
        },
        {
          heading: "4. Information you voluntarily send through Google Forms",
          paragraphs: ["The feedback form uses Google Forms. Feedback, optional reply details, and app version information you enter are sent to Google so we can respond and improve the product. Do not submit images or confidential information."],
        },
        {
          heading: "5. Retention, deletion, and contact",
          paragraphs: ["Form responses are kept only as long as needed to respond. Use the form linked from Support to request deletion or ask about this policy. Google's own policies govern its processing."],
        },
        {
          heading: "6. Changes",
          paragraphs: ["If collection features or third-party SDKs are added, this policy and the App Store privacy disclosure will be updated in the same release."],
        },
      ] satisfies Section[],
    } satisfies LegalDocument,
    terms: {
      title: "Terms of Use",
      eyebrow: "PIXEL FORGE / TERMS",
      summary: "These terms govern use of the Pixel Forge app and its related support website.",
      updated: updatedEn,
      sections: [
        {
          heading: "1. Provider and scope",
          paragraphs: ["The Pixel Forge provider (formal business identity to be finalized before App Store release) provides the app and support website. These terms apply to both. Where they conflict with Apple's Standard EULA, the applicable governing terms take priority."],
        },
        {
          heading: "2. Source images and generated work",
          paragraphs: ["You must have the rights needed to use and transform each source image. Subject to third-party rights, your rights in source images and generated work remain yours."],
        },
        {
          heading: "3. Results and disclaimer",
          paragraphs: ["Conversion results are not guaranteed to be accurate, complete, or fit for a particular purpose. To the extent permitted by law, the provider is not liable for indirect loss arising from use or inability to use the product."],
        },
        {
          heading: "4. Pixel Forge Pro",
          paragraphs: ["Pixel Forge Pro is a buy-once Non-Consumable product offered through the App Store. Apple's systems and terms govern purchase, restoration, and refunds. It is not a subscription."],
        },
        {
          heading: "5. Prohibited conduct",
          paragraphs: ["You may not violate law or third-party rights, interfere with the app or delivery platform, fabricate purchase status, or bypass security mechanisms."],
        },
        {
          heading: "6. Changes, termination, and governing law",
          paragraphs: ["Features or availability may change or end. These terms are governed by Japanese law without limiting mandatory consumer rights. Contact is available through the Support page."],
        },
      ] satisfies Section[],
    } satisfies LegalDocument,
  },
} as const;
