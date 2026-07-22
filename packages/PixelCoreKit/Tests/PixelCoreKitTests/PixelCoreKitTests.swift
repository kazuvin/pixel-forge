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

