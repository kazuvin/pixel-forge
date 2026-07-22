import AppKit
import Foundation
import PixelCoreKit

@MainActor
final class WorkbenchModel: ObservableObject {
    @Published var isShowingImporter = false
    @Published var isRendering = false
    @Published var sourceImage: NSImage?
    @Published var outputImage: NSImage?
    @Published var sourceName = "写真が選択されていません"
    @Published var sourceDimensions = "—"
    @Published var outputDimensions = "—"
    @Published var targetWidth = 64
    @Published var targetHeight = 64
    @Published var colorCount = 12
    @Published var dither: PixelDitherMode = .bayer4x4
    @Published var upscale = 8
    @Published var errorMessage: String?

    private var processor: PixelCoreProcessor?
    private var latestResult: PixelRenderResult?
    private var renderTask: Task<Void, Never>?

    func load(url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            guard let image = NSImage(data: data) else {
                throw WorkbenchError.unsupportedImage
            }
            processor = try PixelCoreProcessor(imageData: data)
            sourceImage = image
            sourceName = url.lastPathComponent
            sourceDimensions = Self.pixelDimensions(from: data)
            outputImage = nil
            latestResult = nil
            errorMessage = nil
            render()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func render() {
        guard let processor else {
            errorMessage = "先に写真を選んでください。"
            return
        }
        let settings = PixelRenderSettings(
            targetWidth: UInt32(targetWidth),
            targetHeight: UInt32(targetHeight),
            colorCount: UInt8(colorCount),
            dither: dither,
            upscale: UInt32(upscale)
        )

        renderTask?.cancel()
        isRendering = true
        errorMessage = nil
        renderTask = Task { [weak self] in
            let outcome = await Task.detached(priority: .userInitiated) {
                do {
                    return RenderOutcome.success(try processor.render(settings))
                } catch {
                    return RenderOutcome.failure(error.localizedDescription)
                }
            }.value
            guard !Task.isCancelled, let self else { return }
            isRendering = false
            switch outcome {
            case let .success(result):
                latestResult = result
                outputImage = NSImage(data: result.pngData)
                outputDimensions = "\(result.width) × \(result.height) px"
            case let .failure(message):
                errorMessage = message
            }
        }
    }

    func export() {
        guard let result = latestResult else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = Self.suggestedOutputName(from: sourceName)
        panel.message = "PNGと同じ場所に再生成用のrecipe JSONも保存します。"
        guard panel.runModal() == .OK, let pngURL = panel.url else { return }

        do {
            try result.pngData.write(to: pngURL, options: .atomic)
            let recipeURL = pngURL.deletingPathExtension().appendingPathExtension("recipe.json")
            try result.recipeJSON.write(to: recipeURL, atomically: true, encoding: .utf8)
            errorMessage = nil
        } catch {
            errorMessage = "書き出せませんでした: \(error.localizedDescription)"
        }
    }

    private static func pixelDimensions(from data: Data) -> String {
        guard let representation = NSBitmapImageRep(data: data) else { return "—" }
        return "\(representation.pixelsWide) × \(representation.pixelsHigh) px"
    }

    private static func suggestedOutputName(from sourceName: String) -> String {
        let stem = (sourceName as NSString).deletingPathExtension
        return "\(stem)-pixel.png"
    }
}

private enum RenderOutcome: Sendable {
    case success(PixelRenderResult)
    case failure(String)
}

private enum WorkbenchError: LocalizedError {
    case unsupportedImage

    var errorDescription: String? {
        "この画像を読み込めませんでした。PNGまたはJPEGを選んでください。"
    }
}

