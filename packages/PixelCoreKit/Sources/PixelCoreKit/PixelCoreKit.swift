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

public struct PixelRGBColor: Codable, Equatable, Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    fileprivate var ffiValue: FfiRgbColor {
        FfiRgbColor(red: red, green: green, blue: blue)
    }
}

public struct PixelCropRect: Codable, Equatable, Hashable, Sendable {
    public let x: UInt32
    public let y: UInt32
    public let width: UInt32
    public let height: UInt32

    public init(x: UInt32, y: UInt32, width: UInt32, height: UInt32) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    fileprivate var ffiValue: FfiCropRect {
        FfiCropRect(x: x, y: y, width: width, height: height)
    }
}

public enum PixelCropRegion: Codable, Equatable, Hashable, Sendable {
    case full
    case rectangle(PixelCropRect)

    fileprivate var ffiValue: FfiCropRegion {
        switch self {
        case .full:
            .full
        case let .rectangle(rect):
            .rectangle(rect: rect.ffiValue)
        }
    }
}

public struct PixelPalette: Codable, Equatable, Hashable, Sendable {
    public let name: String
    public let colors: [PixelRGBColor]

    public init(name: String, colors: [PixelRGBColor]) {
        self.name = name
        self.colors = colors
    }

    fileprivate var ffiValue: FfiPalette {
        FfiPalette(name: name, colors: colors.map(\.ffiValue))
    }
}

public enum PixelPaletteApplication: Codable, Equatable, Hashable, Sendable {
    case exact
    case preserveTone(saturation: UInt8, lightness: UInt8)

    fileprivate var ffiValue: FfiPaletteApplication {
        switch self {
        case .exact:
            .exact
        case let .preserveTone(saturation, lightness):
            .preserveTone(saturation: saturation, lightness: lightness)
        }
    }
}

public enum PixelColorMode: Codable, Equatable, Hashable, Sendable {
    case source
    case palette(PixelPalette, application: PixelPaletteApplication)

    fileprivate var ffiValue: FfiColorMode {
        switch self {
        case .source:
            .source
        case let .palette(palette, application):
            .palette(palette: palette.ffiValue, application: application.ffiValue)
        }
    }
}

public enum PixelOutlineMode: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case none
    case black
    case adaptive

    fileprivate var ffiValue: FfiOutlineMode {
        switch self {
        case .none:
            .none
        case .black:
            .black
        case .adaptive:
            .adaptive
        }
    }
}

public struct PixelOutlineSettings: Codable, Equatable, Hashable, Sendable {
    public var mode: PixelOutlineMode
    public var threshold: UInt8

    public init(mode: PixelOutlineMode = .none, threshold: UInt8 = 15) {
        self.mode = mode
        self.threshold = threshold
    }

    fileprivate var ffiValue: FfiOutlineSettings {
        FfiOutlineSettings(mode: mode.ffiValue, threshold: threshold)
    }
}

public struct PixelConversionSettings: Codable, Equatable, Hashable, Sendable {
    public var longSide: UInt32
    public var upscale: UInt32
    public var crop: PixelCropRegion
    public var colorMode: PixelColorMode
    public var outline: PixelOutlineSettings

    public init(
        longSide: UInt32 = 64,
        upscale: UInt32 = 8,
        crop: PixelCropRegion = .full,
        colorMode: PixelColorMode = .source,
        outline: PixelOutlineSettings = PixelOutlineSettings()
    ) {
        self.longSide = longSide
        self.upscale = upscale
        self.crop = crop
        self.colorMode = colorMode
        self.outline = outline
    }

    fileprivate var ffiValue: FfiRenderSettings {
        FfiRenderSettings(
            longSide: longSide,
            upscale: upscale,
            crop: crop.ffiValue,
            colorMode: colorMode.ffiValue,
            outline: outline.ffiValue
        )
    }
}

public struct PixelRenderResult: Sendable {
    public let pngData: Data
    public let width: UInt32
    public let height: UInt32
    public let palette: [String]
    public let recipeJSON: String
}

public struct PixelImageDimensions: Equatable, Hashable, Sendable {
    public let width: UInt32
    public let height: UInt32

    public init(width: UInt32, height: UInt32) {
        self.width = width
        self.height = height
    }
}

public final class PixelCoreProcessor: @unchecked Sendable {
    private let engine: PixelEngine

    public init(imageData: Data) throws {
        engine = try PixelEngine(imageBytes: imageData)
    }

    public var sourceDimensions: PixelImageDimensions {
        let dimensions = engine.sourceDimensions()
        return PixelImageDimensions(width: dimensions.width, height: dimensions.height)
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

    public func convert(_ settings: PixelConversionSettings) throws -> PixelRenderResult {
        let result = try engine.convert(settings: settings.ffiValue)
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
