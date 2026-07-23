import Foundation
import Photos
import PixelCoreKit
import Testing
@testable import PixelForgeApp

@Suite("Pixel Forge Pro access")
struct ProAccessPolicyTests {
    @Test("free settings remain available without an entitlement")
    func permitsFreeSettings() {
        let settings = PixelConversionSettings(
            longSide: 64,
            upscale: 8,
            crop: .full,
            colorMode: .source,
            outline: .init(mode: .none)
        )

        #expect(ProAccessPolicy.requiredFeatures(for: settings).isEmpty)
        #expect(ProAccessPolicy.canConvert(settings, entitlement: .notPurchased))
    }

    @Test("advanced settings identify every required Pro capability")
    func identifiesProFeatures() {
        let settings = PixelConversionSettings(
            longSide: 96,
            upscale: 4,
            colorMode: .palette(
                PixelPalette(
                    name: "Mono",
                    colors: [.init(red: 0, green: 0, blue: 0)]
                ),
                application: .preserveTone(saturation: 50, lightness: 50)
            ),
            outline: .init(mode: .adaptive, threshold: 20)
        )

        let required = ProAccessPolicy.requiredFeatures(for: settings)
        #expect(required == [
            .customLongSide,
            .customUpscale,
            .palette,
            .tonePreservation,
            .outline,
        ])
        #expect(!ProAccessPolicy.canConvert(settings, entitlement: .notPurchased))
        #expect(ProAccessPolicy.canConvert(settings, entitlement: .purchased))
    }

    @Test("revocation locks future Pro conversion but not library actions")
    func revocationOnlyLocksConversion() {
        #expect(!ProAccessPolicy.isAllowed(.manualTheme, entitlement: .revoked))
        #expect(ProAccessPolicy.isLibraryActionAllowed(.view, entitlement: .revoked))
        #expect(ProAccessPolicy.isLibraryActionAllowed(.saveToPhotos, entitlement: .revoked))
        #expect(ProAccessPolicy.isLibraryActionAllowed(.delete, entitlement: .revoked))
    }
}

@Suite("Photo library save access")
struct PhotoLibraryAccessPolicyTests {
    @Test("only Photos authorization states that allow writes can save")
    func checksAddOnlyAuthorization() {
        #expect(PhotoLibraryAccessPolicy.canSave(status: .authorized))
        #expect(PhotoLibraryAccessPolicy.canSave(status: .limited))
        #expect(!PhotoLibraryAccessPolicy.canSave(status: .notDetermined))
        #expect(!PhotoLibraryAccessPolicy.canSave(status: .denied))
        #expect(!PhotoLibraryAccessPolicy.canSave(status: .restricted))
    }

    @MainActor
    @Test("invalid image bytes fail before Photos receives a request")
    func rejectsInvalidImageData() async {
        var didThrow = false
        do {
            try await SystemPhotoLibrarySaver().savePNG(Data("not-an-image".utf8), filename: "bad.png")
        } catch {
            didThrow = true
        }
        #expect(didThrow)
    }

    @MainActor
    @Test("a valid PNG saves when add-only Photos access is granted")
    func savesValidPNGWhenAuthorized() async throws {
        guard PhotoLibraryAccessPolicy.canSave(
            status: PHPhotoLibrary.authorizationStatus(for: .addOnly)
        ) else {
            return
        }
        let data = try #require(ReviewConfiguration.sourceData)
        try await SystemPhotoLibrarySaver().savePNG(data, filename: "pixel-forge-photo-save-test.png")
    }
}

@Suite("Built-in palette presets")
struct PalettePresetTests {
    @MainActor
    @Test("picker offers thirty-three distinct non-empty presets")
    func providesPaletteCollection() {
        let presets = ConversionSessionModel.palettePresets
        #expect(presets.count == 33)
        #expect(Set(presets.map(\.id)).count == presets.count)
        #expect(Set(presets.map(\.name)).count == presets.count)
        #expect(presets.allSatisfy { !$0.colorValues.isEmpty })
        #expect(presets.allSatisfy { $0.colors.count == $0.colorValues.count })
        #expect(presets.allSatisfy { Set($0.colorValues).count == $0.colorValues.count })
    }

    @MainActor
    @Test("reference palettes keep their native color counts")
    func preservesReferencePaletteColorCounts() {
        let presets = ConversionSessionModel.palettePresets
        let referenceColorCounts = Dictionary(
            uniqueKeysWithValues: presets
                .filter { $0.structure == .reference }
                .map { ($0.id, $0.colorValues.count) }
        )
        #expect(referenceColorCounts == [
            "game-boy": 4,
            "pico-8": 16,
            "c64-pepto": 16,
            "ibm-cga": 16,
            "zx-spectrum": 15,
            "master-system": 64,
            "virtual-boy": 4,
        ])
        #expect(presets.first { $0.id == "game-boy" }?.colorValues == [
            0x0F380F, 0x306230, 0x8BAC0F, 0x9BBC0F,
        ])
        #expect(presets.first { $0.id == "pico-8" }?.colorValues == [
            0x000000, 0x1D2B53, 0x7E2553, 0x008751,
            0xAB5236, 0x5F574F, 0xC2C3C7, 0xFFF1E8,
            0xFF004D, 0xFFA300, 0xFFEC27, 0x00E436,
            0x29ADFF, 0x83769C, 0xFF77A8, 0xFFCCAA,
        ])
    }

    @MainActor
    @Test("creative palettes keep two or three families balanced without a fixed shade count")
    func balancesCreativePaletteFamilies() {
        let presets = ConversionSessionModel.palettePresets
        let creative = presets.filter { $0.structure == .balancedFamilies }
        #expect(creative.count == 24)
        #expect(creative.allSatisfy { preset in
            (preset.colorFamilies.count == 2 || preset.colorFamilies.count == 3)
                && preset.colorFamilies.allSatisfy { $0.count >= 4 }
                && Set(preset.colorFamilies.map(\.count)).count == 1
        })
        #expect(creative.filter { $0.colorFamilies.count == 3 }.count == 6)
        #expect(presets.filter { $0.structure == .tonal }.count == 2)
    }
}

#if PIXEL_FORGE_DEVELOPER
@Suite("Developer Pro override")
struct DeveloperProOverrideTests {
    @MainActor
    @Test("developer builds switch between Free and Pro without StoreKit")
    func switchesAccessState() async {
        let key = "pixel-forge.developer-pro-enabled"
        let previous = UserDefaults.standard.object(forKey: key)
        defer {
            if let previous {
                UserDefaults.standard.set(previous, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let service = ProEntitlementService()
        service.setDeveloperProEnabled(false)
        #expect(service.status == .notPurchased)

        service.setDeveloperProEnabled(true)
        #expect(service.status == .purchased)
    }
}
#endif
