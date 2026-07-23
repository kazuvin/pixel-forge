import SwiftUI
import UIKit

struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var entitlement: ProEntitlementService
    @AppStorage(ForgeTheme.storageKey) private var themeRawValue = ForgeTheme.system.rawValue
    @AppStorage(AppLanguage.storageKey) private var languageRawValue = AppLanguage.system.rawValue
    @State private var proRequirementMessage: String?
    @State private var shareItems: [Any] = []
    @State private var showsShareSheet = false
    @State private var showsLanguageSelector: Bool

    init(opensLanguageSelector: Bool = false) {
        _showsLanguageSelector = State(initialValue: opensLanguageSelector)
    }

    var body: some View {
        ForgeModalScaffold(
            eyebrow: L10n.settingsEyebrow,
            title: L10n.settings,
            detail: L10n.settingsSubtitle,
            close: { dismiss() }
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: ForgeDesign.Spacing.section) {
                    language
                    if AppConfiguration.isDeveloperBuild {
                        developerAccess
                    }
                    appearance
                    pro
                    support
                    about
                }
                .padding(ForgeDesign.Spacing.regular)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .sheet(isPresented: $showsShareSheet) {
            ActivitySheet(items: shareItems)
        }
        .task {
            await entitlement.start()
            enforceAvailableTheme()
        }
        .onChange(of: entitlement.status) { _, _ in
            enforceAvailableTheme()
        }
        .forgeToast(message: $proRequirementMessage, style: .warning)
        .forgeToastContainer()
        .forgeOverlay {
            ForgeSelectionDialog(
                isPresented: $showsLanguageSelector,
                selection: languageSelection,
                eyebrow: L10n.languageEyebrow,
                title: L10n.languageTitle,
                options: languageOptions,
                cancelTitle: L10n.cancel
            )
        }
    }

    private var language: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
            ForgeSectionHeader(
                eyebrow: L10n.languageEyebrow,
                title: L10n.languageTitle,
                detail: L10n.languageDescription
            )
            ForgePixelSelectorButton(
                label: L10n.languageTitle,
                value: selectedLanguageTitle
            ) {
                showsLanguageSelector = true
            }
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
            ForgeSectionHeader(
                eyebrow: L10n.appearanceEyebrow,
                title: L10n.appearanceTitle,
                detail: L10n.appearanceDescription
            )
            VStack(spacing: ForgeDesign.Spacing.compact) {
                ForgeThemeCard(
                    theme: .system,
                    title: L10n.systemTheme,
                    detail: L10n.systemThemeDescription,
                    isSelected: selectedTheme == .system
                ) {
                    select(.system)
                }
                ForgeThemeCard(
                    theme: .dark,
                    title: L10n.darkTheme,
                    detail: L10n.darkThemeDescription,
                    isSelected: selectedTheme == .dark,
                    isLocked: !entitlement.status.isActive
                ) {
                    select(.dark)
                }
                ForgeThemeCard(
                    theme: .light,
                    title: L10n.lightTheme,
                    detail: L10n.lightThemeDescription,
                    isSelected: selectedTheme == .light,
                    isLocked: !entitlement.status.isActive
                ) {
                    select(.light)
                }
            }
        }
    }

    private var developerAccess: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
            ForgeSectionHeader(
                eyebrow: L10n.developerEyebrow,
                title: L10n.developerTitle,
                detail: L10n.developerDescription
            )
            ForgeToggleRow(
                title: L10n.developerProToggle,
                detail: entitlement.developerProEnabled
                    ? L10n.proStatusPurchased
                    : L10n.proStatusFree,
                isOn: developerProSelection
            )
        }
    }

    private var pro: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
            ForgeSectionHeader(
                eyebrow: "NON-CONSUMABLE",
                title: L10n.proTitle
            )
            ForgeProPanel(
                title: L10n.proTitle,
                detail: L10n.proDescription,
                status: entitlementStatus,
                purchaseTitle: purchaseTitle,
                restoreTitle: L10n.restorePurchase,
                canPurchase: entitlement.product != nil && !entitlement.status.isActive,
                purchase: {
                    Task { await entitlement.purchase() }
                },
                restore: {
                    Task { await entitlement.restore() }
                }
            )
        }
    }

    private var support: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
            ForgeSectionHeader(eyebrow: "LINKS", title: L10n.supportTitle)
            ForgeSettingsLinkRow(
                title: L10n.review,
                detail: availabilityDetail(AppConfiguration.appStoreURL),
                isEnabled: AppConfiguration.appStoreURL != nil
            ) {
                open(reviewURL)
            }
            ForgeSettingsLinkRow(
                title: L10n.share,
                detail: availabilityDetail(AppConfiguration.appStoreURL),
                isEnabled: AppConfiguration.appStoreURL != nil
            ) {
                share(AppConfiguration.appStoreURL)
            }
            ForgeSettingsLinkRow(
                title: L10n.feedback,
                detail: availabilityDetail(AppConfiguration.feedbackURL),
                isEnabled: AppConfiguration.feedbackURL != nil
            ) {
                open(AppConfiguration.feedbackURL)
            }
            ForgeSettingsLinkRow(
                title: L10n.privacy,
                detail: availabilityDetail(AppConfiguration.privacyURL()),
                isEnabled: AppConfiguration.privacyURL() != nil
            ) {
                open(AppConfiguration.privacyURL())
            }
            ForgeSettingsLinkRow(
                title: L10n.terms,
                detail: availabilityDetail(AppConfiguration.termsURL()),
                isEnabled: AppConfiguration.termsURL() != nil
            ) {
                open(AppConfiguration.termsURL())
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
            ForgeSectionHeader(eyebrow: "PIXEL FORGE", title: L10n.aboutTitle)
            ForgeAboutRow(title: L10n.version, value: versionLabel)
        }
    }

    private var selectedTheme: ForgeTheme {
        ForgeTheme(rawValue: themeRawValue) ?? .system
    }

    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: languageRawValue) ?? .system },
            set: { languageRawValue = $0.rawValue }
        )
    }

    private var languageOptions: [ForgeSelectionOption<AppLanguage>] {
        [
            ForgeSelectionOption(id: "system", value: .system, title: L10n.languageSystem),
            ForgeSelectionOption(id: "en", value: .english, title: L10n.languageEnglish),
            ForgeSelectionOption(id: "ja", value: .japanese, title: L10n.languageJapanese),
            ForgeSelectionOption(id: "ko", value: .korean, title: L10n.languageKorean),
            ForgeSelectionOption(
                id: "zh-Hant",
                value: .traditionalChinese,
                title: L10n.languageTraditionalChinese
            ),
        ]
    }

    private var selectedLanguageTitle: String {
        switch languageSelection.wrappedValue {
        case .system:
            L10n.languageSystem
        case .english:
            L10n.languageEnglish
        case .japanese:
            L10n.languageJapanese
        case .korean:
            L10n.languageKorean
        case .traditionalChinese:
            L10n.languageTraditionalChinese
        }
    }

    private var developerProSelection: Binding<Bool> {
        Binding(
            get: { entitlement.developerProEnabled },
            set: { entitlement.setDeveloperProEnabled($0) }
        )
    }

    private var purchaseTitle: String {
        if let price = entitlement.displayPrice {
            return "\(L10n.purchase) · \(price)"
        }
        return L10n.purchase
    }

    private var entitlementStatus: String {
        switch entitlement.status {
        case .unknown:
            L10n.proStatusUnknown
        case .loading:
            L10n.proStatusLoading
        case .notPurchased:
            L10n.proStatusFree
        case .pending:
            L10n.proStatusPending
        case .purchased:
            L10n.proStatusPurchased
        case .revoked:
            L10n.proStatusRevoked
        case .failed:
            L10n.proStatusFailed
        }
    }

    private var reviewURL: URL? {
        guard let url = AppConfiguration.appStoreURL else { return nil }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: "action", value: "write-review"))
        components.queryItems = items
        return components.url
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "0.1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "dev"
        return "\(version) (\(build))"
    }

    private func select(_ theme: ForgeTheme) {
        if theme != .system, !entitlement.status.isActive {
            proRequirementMessage = L10n.proRequired
            return
        }
        proRequirementMessage = nil
        themeRawValue = theme.rawValue
    }

    private func enforceAvailableTheme() {
        if !entitlement.status.isActive, selectedTheme != .system {
            themeRawValue = ForgeTheme.system.rawValue
        }
    }

    private func availabilityDetail(_ url: URL?) -> String? {
        url == nil ? L10n.unavailableUntilConfigured : nil
    }

    private func open(_ url: URL?) {
        guard let url else { return }
        UIApplication.shared.open(url)
    }

    private func share(_ url: URL?) {
        guard let url else { return }
        shareItems = [url]
        showsShareSheet = true
    }
}
