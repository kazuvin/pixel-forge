import PixelCoreKit

enum ProFeature: CaseIterable, Equatable, Sendable {
    case customLongSide
    case customUpscale
    case palette
    case tonePreservation
    case outline
    case manualTheme
}

enum ProEntitlementStatus: Equatable, Sendable {
    case unknown
    case loading
    case notPurchased
    case pending
    case purchased
    case revoked
    case failed(String)

    var isActive: Bool {
        self == .purchased
    }
}

enum LibraryAction: Sendable {
    case view
    case export
    case delete
}

enum ProAccessPolicy {
    static let freeLongSides: Set<UInt32> = [32, 64, 128]

    static func requiredFeatures(for settings: PixelConversionSettings) -> [ProFeature] {
        var features: [ProFeature] = []
        if !freeLongSides.contains(settings.longSide) {
            features.append(.customLongSide)
        }
        if settings.upscale != 8 {
            features.append(.customUpscale)
        }
        switch settings.colorMode {
        case .source:
            break
        case let .palette(_, application):
            features.append(.palette)
            if case .preserveTone = application {
                features.append(.tonePreservation)
            }
        }
        if settings.outline.mode != .none {
            features.append(.outline)
        }
        return features
    }

    static func canConvert(
        _ settings: PixelConversionSettings,
        entitlement: ProEntitlementStatus
    ) -> Bool {
        requiredFeatures(for: settings).isEmpty || entitlement.isActive
    }

    static func isAllowed(
        _ feature: ProFeature,
        entitlement: ProEntitlementStatus
    ) -> Bool {
        entitlement.isActive
    }

    static func isLibraryActionAllowed(
        _ action: LibraryAction,
        entitlement: ProEntitlementStatus
    ) -> Bool {
        true
    }
}
