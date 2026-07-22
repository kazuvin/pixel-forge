import Foundation
import PixelCoreKit

struct StoredRecipe: Sendable {
    let settings: PixelConversionSettings
    let metadata: GeneratedImageMetadata

    init(json: String) throws {
        guard let data = json.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawSettings = root["settings"] as? [String: Any]
        else {
            throw StoredRecipeError.invalidDocument
        }

        let longSide = try Self.uint32(rawSettings, "longSide")
        let upscale = try Self.uint32(rawSettings, "upscale")
        let crop = try Self.crop(rawSettings["crop"])
        let colorMode = try Self.colorMode(rawSettings["colorMode"])
        let outline = try Self.outline(rawSettings["outline"])
        settings = PixelConversionSettings(
            longSide: longSide,
            upscale: upscale,
            crop: crop,
            colorMode: colorMode,
            outline: outline
        )

        metadata = GeneratedImageMetadata(
            logicalWidth: try Self.uint32(root, "logicalWidth"),
            logicalHeight: try Self.uint32(root, "logicalHeight"),
            outputWidth: try Self.uint32(root, "outputWidth"),
            outputHeight: try Self.uint32(root, "outputHeight"),
            paletteName: Self.paletteName(from: colorMode),
            algorithmVersion: root["algorithmVersion"] as? String ?? "unknown"
        )
    }

    private static func crop(_ value: Any?) throws -> PixelCropRegion {
        guard let dictionary = value as? [String: Any], let mode = dictionary["mode"] as? String else {
            throw StoredRecipeError.invalidSettings("crop")
        }
        if mode == "full" {
            return .full
        }
        guard mode == "rectangle", let rect = dictionary["rect"] as? [String: Any] else {
            throw StoredRecipeError.invalidSettings("crop")
        }
        return .rectangle(
            PixelCropRect(
                x: try uint32(rect, "x"),
                y: try uint32(rect, "y"),
                width: try uint32(rect, "width"),
                height: try uint32(rect, "height")
            )
        )
    }

    private static func colorMode(_ value: Any?) throws -> PixelColorMode {
        guard let dictionary = value as? [String: Any], let mode = dictionary["mode"] as? String else {
            throw StoredRecipeError.invalidSettings("colorMode")
        }
        if mode == "source" {
            return .source
        }
        guard mode == "palette",
              let rawPalette = dictionary["palette"] as? [String: Any],
              let name = rawPalette["name"] as? String,
              let rawColors = rawPalette["colors"] as? [[String: Any]]
        else {
            throw StoredRecipeError.invalidSettings("palette")
        }
        let colors = try rawColors.map {
            PixelRGBColor(
                red: try uint8($0, "red"),
                green: try uint8($0, "green"),
                blue: try uint8($0, "blue")
            )
        }
        let palette = PixelPalette(name: name, colors: colors)
        let application = try paletteApplication(dictionary["application"])
        return .palette(palette, application: application)
    }

    private static func paletteApplication(_ value: Any?) throws -> PixelPaletteApplication {
        guard let dictionary = value as? [String: Any], let mode = dictionary["mode"] as? String else {
            throw StoredRecipeError.invalidSettings("paletteApplication")
        }
        if mode == "exact" {
            return .exact
        }
        guard mode == "preserve-tone",
              let preservation = dictionary["preservation"] as? [String: Any]
        else {
            throw StoredRecipeError.invalidSettings("paletteApplication")
        }
        return .preserveTone(
            saturation: try uint8(preservation, "saturation"),
            lightness: try uint8(preservation, "lightness")
        )
    }

    private static func outline(_ value: Any?) throws -> PixelOutlineSettings {
        guard let dictionary = value as? [String: Any],
              let rawMode = dictionary["mode"] as? String,
              let mode = PixelOutlineMode(rawValue: rawMode)
        else {
            throw StoredRecipeError.invalidSettings("outline")
        }
        return PixelOutlineSettings(mode: mode, threshold: try uint8(dictionary, "threshold"))
    }

    private static func paletteName(from colorMode: PixelColorMode) -> String? {
        if case let .palette(palette, _) = colorMode {
            return palette.name
        }
        return nil
    }

    private static func uint32(_ dictionary: [String: Any], _ key: String) throws -> UInt32 {
        guard let number = dictionary[key] as? NSNumber else {
            throw StoredRecipeError.invalidSettings(key)
        }
        return number.uint32Value
    }

    private static func uint8(_ dictionary: [String: Any], _ key: String) throws -> UInt8 {
        guard let number = dictionary[key] as? NSNumber, number.uint64Value <= UInt8.max else {
            throw StoredRecipeError.invalidSettings(key)
        }
        return number.uint8Value
    }
}

enum StoredRecipeError: Error, Equatable {
    case invalidDocument
    case invalidSettings(String)
}
