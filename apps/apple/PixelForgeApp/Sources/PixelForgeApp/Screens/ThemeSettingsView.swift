import AppKit
import SwiftUI

struct ThemeSettingsView: View {
    @EnvironmentObject private var entitlement: ProEntitlementService
    @AppStorage(ForgeTheme.storageKey) private var themeRawValue = ForgeTheme.system.rawValue
    @State private var showsProExplanation = false

    var body: some View {
        ForgeCanvas {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeDesign.Spacing.section) {
                    appearance
                    pro
                    support
                    about
                }
                .padding(ForgeDesign.Spacing.roomy)
            }
        }
        .frame(width: 760, height: 720)
        .task {
            await entitlement.start()
            enforceAvailableTheme()
        }
        .onChange(of: entitlement.status) { _, _ in
            enforceAvailableTheme()
        }
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
            ForgeSectionHeader(
                eyebrow: L10n.appearanceEyebrow,
                title: L10n.appearanceTitle,
                detail: L10n.appearanceDescription
            )
            HStack(spacing: ForgeDesign.Spacing.compact) {
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
            if showsProExplanation {
                ForgeAlertBanner(message: L10n.proRequired)
            }
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
            showsProExplanation = true
            return
        }
        showsProExplanation = false
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
        NSWorkspace.shared.open(url)
    }

    private func share(_ url: URL?) {
        guard let url,
              let contentView = NSApp.keyWindow?.contentView
        else { return }
        NSSharingServicePicker(items: [url]).show(
            relativeTo: contentView.bounds,
            of: contentView,
            preferredEdge: .minY
        )
    }
}
