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
