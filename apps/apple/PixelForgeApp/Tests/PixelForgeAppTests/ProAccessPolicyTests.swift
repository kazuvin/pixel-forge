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
    @Test("picker offers twenty-four distinct non-empty presets")
    func providesPaletteCollection() {
        let presets = ConversionSessionModel.palettePresets
        #expect(presets.count == 24)
        #expect(Set(presets.map(\.id)).count == presets.count)
        #expect(Set(presets.map(\.name)).count == presets.count)
        #expect(presets.allSatisfy { !$0.colorValues.isEmpty })
        #expect(presets.allSatisfy { $0.colors.count == $0.colorValues.count })
        #expect(presets.allSatisfy { Set($0.colorValues).count == $0.colorValues.count })
    }

    @MainActor
    @Test("every palette family has six shades and paired palettes stay balanced")
    func balancesPaletteFamilies() {
        let presets = ConversionSessionModel.palettePresets
        #expect(presets.allSatisfy { preset in
            (preset.colorFamilies.count == 1 || preset.colorFamilies.count == 2)
                && preset.colorFamilies.allSatisfy { $0.count == 6 }
        })
        #expect(presets.filter { $0.colorFamilies.count == 1 }.count == 3)
        #expect(presets.filter { $0.colorFamilies.count == 2 }.count == 21)
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
