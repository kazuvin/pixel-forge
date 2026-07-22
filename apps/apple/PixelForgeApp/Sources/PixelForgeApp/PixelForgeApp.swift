import SwiftUI

@main
struct PixelForgeApp: App {
    @AppStorage(ForgeTheme.storageKey) private var storedTheme = ForgeTheme.system.rawValue
    @StateObject private var entitlement = ProEntitlementService()

    init() {
        ForgeFont.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            WorkbenchView(
                initialURL: launchInputURL,
                reviewCaptureURL: reviewCaptureURL
            )
                .frame(minWidth: 980, minHeight: 640)
                .forgeTheme(activeTheme)
                .environmentObject(entitlement)
        }
        .defaultSize(width: 1_180, height: 760)
        .windowStyle(.hiddenTitleBar)

        Settings {
            ThemeSettingsView()
                .forgeTheme(activeTheme)
                .environmentObject(entitlement)
        }
        .windowResizability(.contentSize)
    }

    private var activeTheme: ForgeTheme {
        if let launchTheme {
            return launchTheme
        }
        let selected = ForgeTheme(rawValue: storedTheme) ?? .system
        return selected == .system || entitlement.status.isActive ? selected : .system
    }

    private var launchTheme: ForgeTheme? {
        argumentValue(after: "--theme").flatMap(ForgeTheme.init(rawValue:))
    }

    private var launchInputURL: URL? {
        argumentValue(after: "--open").map { URL(fileURLWithPath: $0) }
    }

    private var reviewCaptureURL: URL? {
        argumentValue(after: "--capture-review").map { URL(fileURLWithPath: $0) }
    }

    private func argumentValue(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag) else { return nil }
        let valueIndex = arguments.index(after: index)
        guard valueIndex < arguments.endIndex else { return nil }
        return arguments[valueIndex]
    }
}
