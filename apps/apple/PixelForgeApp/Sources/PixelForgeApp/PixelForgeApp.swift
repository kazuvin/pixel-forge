import SwiftUI

@main
struct PixelForgeApp: App {
    @AppStorage(ForgeTheme.storageKey) private var storedTheme = ForgeTheme.system.rawValue
    @AppStorage(AppLanguage.storageKey) private var storedLanguage = AppLanguage.system.rawValue
    @StateObject private var entitlement: ProEntitlementService
    private let reviewConfiguration: ReviewConfiguration?

    init() {
        let reviewConfiguration = ReviewConfiguration.current
        self.reviewConfiguration = reviewConfiguration
        _entitlement = StateObject(
            wrappedValue: ProEntitlementService(
                reviewStatus: reviewConfiguration == nil ? nil : .notPurchased
            )
        )
        ForgeFont.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WorkbenchView(reviewScreen: reviewConfiguration?.screen)
            }
            .forgeTheme(activeTheme)
            .environment(\.locale, activeLanguage.locale)
            .environmentObject(entitlement)
        }
    }

    private var activeTheme: ForgeTheme {
        if let reviewConfiguration {
            return reviewConfiguration.theme
        }
        let selected = ForgeTheme(rawValue: storedTheme) ?? .system
        return selected == .system || entitlement.status.isActive ? selected : .system
    }

    private var activeLanguage: AppLanguage {
        if let reviewConfiguration {
            return reviewConfiguration.language
        }
        return AppLanguage(rawValue: storedLanguage) ?? .system
    }
}
