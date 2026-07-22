import AppKit

enum ReviewCapture {
    @MainActor
    static func saveMainWindow(to url: URL) {
        guard
            let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }),
            let contentView = window.contentView,
            let representation = contentView.bitmapImageRepForCachingDisplay(in: contentView.bounds)
        else {
            terminate(with: 2)
        }

        window.displayIfNeeded()
        contentView.displayIfNeeded()
        contentView.cacheDisplay(in: contentView.bounds, to: representation)

        guard let pngData = representation.representation(using: .png, properties: [:]) else {
            terminate(with: 3)
        }

        do {
            try pngData.write(to: url, options: .atomic)
            NSApplication.shared.terminate(nil)
        } catch {
            fputs("review capture failed: \(error.localizedDescription)\n", stderr)
            terminate(with: 4)
        }
    }

    @MainActor
    private static func terminate(with status: Int32) -> Never {
        NSApplication.shared.terminate(nil)
        exit(status)
    }
}
