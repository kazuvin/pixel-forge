import Foundation
import Testing
@testable import PixelCoreKit

@Test("Swift binding renders PNG and recipe through the Rust engine")
func rendersThroughRustEngine() throws {
    let ppm = """
    P3
    2 2
    255
    255 0 0   0 255 0
    0 0 255   255 255 255
    """
    let processor = try PixelCoreProcessor(imageData: Data(ppm.utf8))
    #expect(processor.sourceDimensions == PixelImageDimensions(width: 2, height: 2))

    let result = try processor.render(
        PixelRenderSettings(
            targetWidth: 2,
            targetHeight: 2,
            colorCount: 4,
            dither: .none,
            upscale: 3
        )
    )

    #expect(result.pngData.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    #expect(result.width == 6)
    #expect(result.height == 6)
    #expect(result.recipeJSON.contains("\"algorithmVersion\""))
}

@Test("Swift API exposes the canonical crop, palette, tone, and outline contract")
func convertsThroughCanonicalContract() throws {
    let ppm = """
    P3
    3 2
    255
    255 0 0   0 255 0   0 0 255
    255 255 255   0 0 0   128 128 128
    """
    let processor = try PixelCoreProcessor(imageData: Data(ppm.utf8))
    let palette = PixelPalette(
        name: "Test",
        colors: [
            PixelRGBColor(red: 0, green: 0, blue: 0),
            PixelRGBColor(red: 255, green: 255, blue: 255),
        ]
    )

    let result = try processor.convert(
        PixelConversionSettings(
            longSide: 3,
            upscale: 2,
            crop: .rectangle(PixelCropRect(x: 0, y: 0, width: 3, height: 2)),
            colorMode: .palette(
                palette,
                application: .preserveTone(saturation: 60, lightness: 70)
            ),
            outline: PixelOutlineSettings(mode: .adaptive, threshold: 15)
        )
    )

    #expect(result.width == 6)
    #expect(result.height == 4)
    #expect(result.recipeJSON.contains("\"schemaVersion\": 2"))
    #expect(result.recipeJSON.contains("\"algorithmVersion\": \"1.2.0\""))
}
