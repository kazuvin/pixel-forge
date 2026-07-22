import PixelCoreKit
import Testing
@testable import PixelForgeApp

@Test("stored Rust recipe restores every editable conversion setting")
func restoresSettingsFromStoredRecipe() throws {
    let json = """
    {
      "schemaVersion": 2,
      "algorithmVersion": "1.2.0",
      "settings": {
        "longSide": 96,
        "upscale": 4,
        "crop": { "mode": "rectangle", "rect": { "x": 2, "y": 3, "width": 40, "height": 30 } },
        "colorMode": {
          "mode": "palette",
          "palette": { "name": "Mono", "colors": [{"red": 0, "green": 1, "blue": 2}] },
          "application": {
            "mode": "preserve-tone",
            "preservation": { "saturation": 55, "lightness": 65 }
          }
        },
        "outline": { "mode": "adaptive", "threshold": 22 }
      },
      "logicalWidth": 96,
      "logicalHeight": 72,
      "outputWidth": 384,
      "outputHeight": 288,
      "palette": ["#000102"]
    }
    """

    let recipe = try StoredRecipe(json: json)

    #expect(recipe.settings.longSide == 96)
    #expect(recipe.settings.upscale == 4)
    #expect(recipe.settings.crop == .rectangle(.init(x: 2, y: 3, width: 40, height: 30)))
    #expect(recipe.settings.colorMode == .palette(
        .init(name: "Mono", colors: [.init(red: 0, green: 1, blue: 2)]),
        application: .preserveTone(saturation: 55, lightness: 65)
    ))
    #expect(recipe.settings.outline == .init(mode: .adaptive, threshold: 22))
    #expect(recipe.metadata.logicalHeight == 72)
}
