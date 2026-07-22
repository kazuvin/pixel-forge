import Foundation
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

@MainActor
@Test("adjust restores every parameter from the last rendered recipe")
func adjustRestoresLastRenderedSettings() throws {
    let sourceData = try #require(ReviewConfiguration.sourceData)
    let version = PixelCoreInfo.algorithmVersion
    let model = try ConversionSessionModel(
        record: record(algorithmVersion: version),
        sourceData: sourceData,
        pngData: sourceData,
        recipeJSON: recipeJSON(algorithmVersion: version),
        store: LocalLibraryStore(rootURL: temporaryDirectory()),
        presetStore: ConversionPresetStore(rootURL: temporaryDirectory()),
        entitlement: ProEntitlementService(),
        onLibraryChange: {}
    )

    model.longSide = 12
    model.upscale = 2
    model.paletteSelection = .source
    model.outlineMode = .none
    model.edit()

    #expect(model.longSide == 96)
    #expect(model.upscale == 4)
    #expect(model.paletteSelection == .custom)
    #expect(model.customPaletteColorValues == [0x000102])
    #expect(model.preservesTone)
    #expect(model.saturation == 55)
    #expect(model.lightness == 65)
    #expect(model.outlineMode == .adaptive)
    #expect(model.outlineThreshold == 22)
    #expect(model.settingsCompatibilityWarning == nil)
}

@MainActor
@Test("adjust warns and falls back to defaults after an algorithm version change")
func adjustFallsBackWhenAlgorithmChanges() throws {
    let sourceData = try #require(ReviewConfiguration.sourceData)
    let oldVersion = "0.0.1"
    let model = try ConversionSessionModel(
        record: record(algorithmVersion: oldVersion),
        sourceData: sourceData,
        pngData: sourceData,
        recipeJSON: recipeJSON(algorithmVersion: oldVersion),
        store: LocalLibraryStore(rootURL: temporaryDirectory()),
        presetStore: ConversionPresetStore(rootURL: temporaryDirectory()),
        entitlement: ProEntitlementService(),
        onLibraryChange: {}
    )

    model.edit()

    #expect(model.longSide == 64)
    #expect(model.upscale == 8)
    #expect(model.paletteSelection == .source)
    #expect(!model.preservesTone)
    #expect(model.outlineMode == .none)
    #expect(model.outlineThreshold == 15)
    #expect(model.settingsCompatibilityWarning?.contains(oldVersion) == true)
    #expect(model.settingsCompatibilityWarning?.contains(PixelCoreInfo.algorithmVersion) == true)
}

@MainActor
@Test("saved presets apply compatible settings and reject an old algorithm version")
func appliesCompatiblePresetAndRejectsOldVersion() throws {
    let sourceData = try #require(ReviewConfiguration.sourceData)
    let model = try ConversionSessionModel(
        sourceData: sourceData,
        sourceFilename: "test.png",
        store: LocalLibraryStore(rootURL: temporaryDirectory()),
        presetStore: ConversionPresetStore(rootURL: temporaryDirectory()),
        entitlement: ProEntitlementService(),
        onLibraryChange: {}
    )
    let now = Date(timeIntervalSince1970: 10)
    let settings = PixelConversionSettings(
        longSide: 80,
        upscale: 6,
        colorMode: .palette(
            PixelPalette(name: "Custom", colors: [.init(red: 12, green: 34, blue: 56)]),
            application: .exact
        ),
        outline: .init(mode: .black, threshold: 30)
    )
    let compatible = SavedConversionPreset(
        id: UUID(),
        name: "Compatible",
        settings: settings,
        algorithmVersion: PixelCoreInfo.algorithmVersion,
        createdAt: now,
        updatedAt: now
    )

    model.applyPreset(compatible)
    #expect(model.longSide == 80)
    #expect(model.upscale == 6)
    #expect(model.paletteSelection == .custom)
    #expect(model.customPaletteColorValues == [0x0C2238])
    #expect(model.outlineMode == .black)
    #expect(model.outlineThreshold == 30)
    #expect(model.settingsCompatibilityWarning == nil)

    let incompatible = SavedConversionPreset(
        id: UUID(),
        name: "Old",
        settings: settings,
        algorithmVersion: "0.0.1",
        createdAt: now,
        updatedAt: now
    )
    model.applyPreset(incompatible)
    #expect(model.longSide == 64)
    #expect(model.upscale == 8)
    #expect(model.paletteSelection == .source)
    #expect(model.settingsCompatibilityWarning?.contains("0.0.1") == true)
}

@MainActor
@Test("adjust restores a saved preset as the selected conversion style")
func adjustRestoresSavedPresetSelection() async throws {
    let sourceData = try #require(ReviewConfiguration.sourceData)
    let presetRoot = temporaryDirectory()
    let presetStore = ConversionPresetStore(rootURL: presetRoot)
    let settings = PixelConversionSettings(
        longSide: 96,
        upscale: 4,
        colorMode: .palette(
            PixelPalette(name: "Mono", colors: [.init(red: 0, green: 1, blue: 2)]),
            application: .preserveTone(saturation: 55, lightness: 65)
        ),
        outline: .init(mode: .adaptive, threshold: 22)
    )
    let saved = try await presetStore.savePreset(
        name: "Portrait Lab",
        settings: settings,
        algorithmVersion: PixelCoreInfo.algorithmVersion
    )
    let model = try ConversionSessionModel(
        record: record(
            algorithmVersion: PixelCoreInfo.algorithmVersion,
            presetReference: .saved(saved.id)
        ),
        sourceData: sourceData,
        pngData: sourceData,
        recipeJSON: recipeJSON(algorithmVersion: PixelCoreInfo.algorithmVersion),
        store: LocalLibraryStore(rootURL: temporaryDirectory()),
        presetStore: presetStore,
        entitlement: ProEntitlementService(),
        onLibraryChange: {}
    )

    await model.loadPresets()
    model.edit()

    #expect(model.isSavedPresetSelected(saved))
    #expect(model.selectedConversionStyleTitle == "Portrait Lab")
}

private func record(
    algorithmVersion: String,
    presetReference: ConversionPresetReference? = nil
) -> GeneratedImageRecord {
    GeneratedImageRecord(
        id: UUID(),
        sourceHash: "test-source",
        sourceFilename: "test.png",
        pngRelativePath: "test/output.png",
        recipeRelativePath: "test/recipe.json",
        createdAt: Date(timeIntervalSince1970: 10),
        updatedAt: Date(timeIntervalSince1970: 10),
        metadata: GeneratedImageMetadata(
            logicalWidth: 96,
            logicalHeight: 72,
            outputWidth: 384,
            outputHeight: 288,
            paletteName: "Mono",
            algorithmVersion: algorithmVersion
        ),
        presetReference: presetReference
    )
}

private func recipeJSON(algorithmVersion: String) -> String {
    """
    {
      "schemaVersion": 2,
      "algorithmVersion": "\(algorithmVersion)",
      "settings": {
        "longSide": 96,
        "upscale": 4,
        "crop": { "mode": "full" },
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
      "outputHeight": 288
    }
    """
}

private func temporaryDirectory() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("PixelForgeRecipeTests-\(UUID().uuidString)", isDirectory: true)
}
