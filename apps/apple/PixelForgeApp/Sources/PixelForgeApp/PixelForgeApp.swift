import SwiftUI

@main
struct PixelForgeApp: App {
    var body: some Scene {
        WindowGroup {
            WorkbenchView()
                .frame(minWidth: 980, minHeight: 640)
        }
        .defaultSize(width: 1_180, height: 760)
        .windowStyle(.hiddenTitleBar)
    }
}

