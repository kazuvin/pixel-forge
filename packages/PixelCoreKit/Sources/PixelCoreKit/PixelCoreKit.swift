import Foundation

public enum PixelDitherMode: String, CaseIterable, Identifiable, Sendable {
    case none
    case bayer4x4
    case floydSteinberg

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .none:
            "なし"
        case .bayer4x4:
            "Bayer"
        case .floydSteinberg:
            "Floyd"
        }
    }

    fileprivate var ffiValue: FfiDitherMode {
        switch self {
        case .none:
            .none
        case .bayer4x4:
            .bayer4x4
        case .floydSteinberg:
            .floydSteinberg
        }
    }
}

public struct PixelRenderSettings: Equatable, Sendable {
    public var targetWidth: UInt32
    public var targetHeight: UInt32
    public var colorCount: UInt8
    public var dither: PixelDitherMode
    public var upscale: UInt32

    public init(
        targetWidth: UInt32 = 64,
        targetHeight: UInt32 = 64,
        colorCount: UInt8 = 12,
        dither: PixelDitherMode = .bayer4x4,
        upscale: UInt32 = 8
    ) {
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
        self.colorCount = colorCount
        self.dither = dither
        self.upscale = upscale
    }
}

public struct PixelRenderResult: Sendable {
    public let pngData: Data
    public let width: UInt32
    public let height: UInt32
    public let palette: [String]
    public let recipeJSON: String
}

public final class PixelCoreProcessor: @unchecked Sendable {
    private let engine: PixelEngine

    public init(imageData: Data) throws {
        engine = try PixelEngine(imageBytes: imageData)
    }

    public func render(_ settings: PixelRenderSettings) throws -> PixelRenderResult {
        let result = try engine.render(
            settings: FfiPixelSettings(
                targetWidth: settings.targetWidth,
                targetHeight: settings.targetHeight,
                colorCount: settings.colorCount,
                dither: settings.dither.ffiValue,
                upscale: settings.upscale
            )
        )
        return PixelRenderResult(
            pngData: result.pngBytes,
            width: result.width,
            height: result.height,
            palette: result.palette,
            recipeJSON: result.recipeJson
        )
    }
}

public enum PixelCoreInfo {
    public static var algorithmVersion: String {
        PixelCoreKit.algorithmVersion()
    }
}
