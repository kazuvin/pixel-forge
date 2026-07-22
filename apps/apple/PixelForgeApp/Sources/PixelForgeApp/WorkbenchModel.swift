import Foundation
import Photos
import PixelCoreKit
import UIKit

@MainActor
final class HomeModel: ObservableObject {
    @Published var records: [GeneratedImageRecord] = []
    @Published var thumbnails: [UUID: UIImage] = [:]
    @Published var session: ConversionSessionModel?
    @Published var errorMessage: String?

    private let store: LocalLibraryStore
    private let presetStore: ConversionPresetStore

    init(
        store: LocalLibraryStore = LocalLibraryStore(),
        presetStore: ConversionPresetStore = ConversionPresetStore()
    ) {
        self.store = store
        self.presetStore = presetStore
    }

    func loadLibrary() async {
        do {
            let snapshot = try await store.loadSnapshot()
            records = snapshot.records.sorted { $0.createdAt > $1.createdAt }
            var loaded: [UUID: UIImage] = [:]
            for record in records {
                if let image = UIImage(data: try await store.pngData(for: record)) {
                    loaded[record.id] = image
                }
            }
            thumbnails = loaded
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load(
        url: URL,
        entitlement: ProEntitlementService,
        autoConvert: Bool = false
    ) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            let data = try Data(contentsOf: url)
            let newSession = try ConversionSessionModel(
                sourceData: data,
                sourceFilename: url.lastPathComponent,
                store: store,
                presetStore: presetStore,
                entitlement: entitlement,
                onLibraryChange: { [weak self] in
                    await self?.loadLibrary()
                }
            )
            session = newSession
            errorMessage = nil
            if autoConvert {
                newSession.convert(saveMode: .newRecord)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load(data: Data, filename: String, entitlement: ProEntitlementService) {
        do {
            session = try ConversionSessionModel(
                sourceData: data,
                sourceFilename: filename,
                store: store,
                presetStore: presetStore,
                entitlement: entitlement,
                onLibraryChange: { [weak self] in
                    await self?.loadLibrary()
                }
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func prepareReviewHome(imageData: Data) {
        guard let image = UIImage(data: imageData) else { return }
        let baseDate = Date(timeIntervalSince1970: 1_751_328_000)
        let sizes: [(logical: UInt32, output: UInt32)] = [(64, 512), (32, 256)]
        records = sizes.enumerated().map { index, size in
            GeneratedImageRecord(
                id: UUID(),
                sourceHash: "review-\(index)",
                sourceFilename: "pixel-study-0\(index + 1).png",
                pngRelativePath: "review/\(index).png",
                recipeRelativePath: "review/\(index).json",
                createdAt: baseDate.addingTimeInterval(Double(index) * 60),
                updatedAt: baseDate.addingTimeInterval(Double(index) * 60),
                metadata: GeneratedImageMetadata(
                    logicalWidth: size.logical,
                    logicalHeight: size.logical,
                    outputWidth: size.output,
                    outputHeight: size.output,
                    paletteName: index == 0 ? "Source" : "PICO-8",
                    algorithmVersion: PixelCoreInfo.algorithmVersion
                )
            )
        }
        thumbnails = Dictionary(uniqueKeysWithValues: records.map { ($0.id, image) })
        errorMessage = nil
    }

    func open(_ record: GeneratedImageRecord, entitlement: ProEntitlementService) async {
        do {
            let source = try await store.sourceData(for: record)
            let png = try await store.pngData(for: record)
            let recipe = try await store.recipeJSON(for: record)
            session = try ConversionSessionModel(
                record: record,
                sourceData: source,
                pngData: png,
                recipeJSON: recipe,
                store: store,
                presetStore: presetStore,
                entitlement: entitlement,
                onLibraryChange: { [weak self] in
                    await self?.loadLibrary()
                }
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ record: GeneratedImageRecord) async {
        do {
            try await store.deleteRecord(id: record.id)
            await loadLibrary()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

enum ConversionModalState: Equatable {
    case editing
    case rendering
    case result
    case failure
}

enum ConversionSaveMode {
    case newRecord
    case update
}

enum PaletteSelection: Hashable {
    case source
    case preset(String)
    case custom
}

struct PalettePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let colorValues: [UInt32]

    var colors: [PixelRGBColor] {
        colorValues.map { value in
            PixelRGBColor(
                red: UInt8((value >> 16) & 0xFF),
                green: UInt8((value >> 8) & 0xFF),
                blue: UInt8(value & 0xFF)
            )
        }
    }

    var displayName: String {
        switch id {
        case "game-boy": L10n.palettePresetGameBoy
        case "pico-8": L10n.palettePresetPico8
        case "mono-ink": L10n.palettePresetMonoInk
        case "ocean-8": L10n.palettePresetOcean8
        case "sunset-8": L10n.palettePresetSunset8
        case "forest-8": L10n.palettePresetForest8
        case "candy-8": L10n.palettePresetCandy8
        case "sepia-6": L10n.palettePresetSepia6
        default: name
        }
    }
}

@MainActor
final class ConversionSessionModel: ObservableObject, Identifiable {
    let id = UUID()
    let sourceData: Data
    let sourceFilename: String
    let sourceImage: UIImage?
    let sourceDimensions: PixelImageDimensions

    @Published var state: ConversionModalState
    @Published var showsLoader = false
    @Published var outputImage: UIImage?
    @Published var errorMessage: String?
    @Published var requiresPro = false
    @Published var currentRecord: GeneratedImageRecord?
    @Published var photoSaveState: PhotoSaveState = .idle
    @Published var settingsCompatibilityWarning: String?
    @Published private(set) var savedPresets: [SavedConversionPreset] = []
    @Published var presetSuccessMessage: String?
    @Published var presetErrorMessage: String?

    @Published var longSide = 64
    @Published var upscale = 8
    @Published var paletteSelection: PaletteSelection = .source
    @Published var customPaletteText = "#000000, #FFFFFF"
    @Published var preservesTone = false
    @Published var saturation = 50
    @Published var lightness = 50
    @Published var outlineMode: PixelOutlineMode = .none
    @Published var outlineThreshold = 15

    private let store: LocalLibraryStore
    private let presetStore: ConversionPresetStore
    private let entitlement: ProEntitlementService
    private let photoLibrarySaver: any PhotoLibrarySaving
    private let onLibraryChange: @MainActor () async -> Void
    private var latestPNGData: Data?
    private var lastRenderedSettings: PixelConversionSettings?
    private var lastRenderedAlgorithmVersion: String?
    private var conversionTask: Task<Void, Never>?
    private var loaderTask: Task<Void, Never>?

    init(
        sourceData: Data,
        sourceFilename: String,
        store: LocalLibraryStore,
        presetStore: ConversionPresetStore = ConversionPresetStore(),
        entitlement: ProEntitlementService,
        photoLibrarySaver: any PhotoLibrarySaving = SystemPhotoLibrarySaver(),
        onLibraryChange: @escaping @MainActor () async -> Void
    ) throws {
        let processor = try PixelCoreProcessor(imageData: sourceData)
        self.sourceData = sourceData
        self.sourceFilename = sourceFilename
        sourceImage = UIImage(data: sourceData)
        sourceDimensions = processor.sourceDimensions
        state = .editing
        self.store = store
        self.presetStore = presetStore
        self.entitlement = entitlement
        self.photoLibrarySaver = photoLibrarySaver
        self.onLibraryChange = onLibraryChange
    }

    init(
        record: GeneratedImageRecord,
        sourceData: Data,
        pngData: Data,
        recipeJSON: String,
        store: LocalLibraryStore,
        presetStore: ConversionPresetStore = ConversionPresetStore(),
        entitlement: ProEntitlementService,
        photoLibrarySaver: any PhotoLibrarySaving = SystemPhotoLibrarySaver(),
        onLibraryChange: @escaping @MainActor () async -> Void
    ) throws {
        let processor = try PixelCoreProcessor(imageData: sourceData)
        let recipe = try StoredRecipe(json: recipeJSON)
        self.sourceData = sourceData
        sourceFilename = record.sourceFilename
        sourceImage = UIImage(data: sourceData)
        sourceDimensions = processor.sourceDimensions
        state = .result
        outputImage = UIImage(data: pngData)
        currentRecord = record
        latestPNGData = pngData
        self.store = store
        self.presetStore = presetStore
        self.entitlement = entitlement
        self.photoLibrarySaver = photoLibrarySaver
        self.onLibraryChange = onLibraryChange
        lastRenderedSettings = recipe.settings
        lastRenderedAlgorithmVersion = recipe.metadata.algorithmVersion
        if recipe.metadata.algorithmVersion == PixelCoreInfo.algorithmVersion {
            apply(recipe.settings)
        }
    }

    deinit {
        conversionTask?.cancel()
        loaderTask?.cancel()
    }

    var hasExistingRecord: Bool {
        currentRecord != nil
    }

    var isProActive: Bool {
        entitlement.status.isActive
    }

    var sourceDimensionsLabel: String {
        "\(sourceDimensions.width) × \(sourceDimensions.height) px"
    }

    var outputDimensionsLabel: String {
        guard let record = currentRecord else { return "—" }
        return "\(record.metadata.outputWidth) × \(record.metadata.outputHeight) px"
    }

    var logicalDimensionsLabel: String {
        guard let record = currentRecord else { return "—" }
        return "\(record.metadata.logicalWidth) × \(record.metadata.logicalHeight) px"
    }

    var selectedPaletteTitle: String {
        switch paletteSelection {
        case .source:
            L10n.paletteSource
        case let .preset(identifier):
            Self.palettePresets.first(where: { $0.id == identifier })?.displayName ?? L10n.palette
        case .custom:
            L10n.custom
        }
    }

    var selectedPaletteColorValues: [UInt32] {
        switch paletteSelection {
        case .source:
            []
        case let .preset(identifier):
            Self.palettePresets.first(where: { $0.id == identifier })?.colorValues ?? []
        case .custom:
            customPaletteColorValues
        }
    }

    var customPaletteColorValues: [UInt32] {
        customPaletteText
            .split(separator: ",")
            .compactMap { Self.parseHexValue(String($0)) }
    }

    func edit() {
        errorMessage = nil
        requiresPro = false
        photoSaveState = .idle
        restoreLastRenderedSettings()
        refreshProRequirement()
        state = .editing
    }

    func retry() {
        state = .editing
    }

    func refreshProRequirement() {
        guard !entitlement.status.isActive, let settings = try? makeSettings() else {
            requiresPro = false
            return
        }
        requiresPro = !ProAccessPolicy.requiredFeatures(for: settings).isEmpty
    }

    func loadPresets() async {
        presetSuccessMessage = nil
        do {
            savedPresets = try await presetStore.loadPresets()
            presetErrorMessage = nil
        } catch {
            presetErrorMessage = L10n.presetOperationFailed(error.localizedDescription)
        }
    }

    @discardableResult
    func saveCurrentPreset(named name: String) async -> Bool {
        do {
            let settings = try makeSettings()
            let preset = try await presetStore.savePreset(name: name, settings: settings)
            savedPresets = try await presetStore.loadPresets()
            presetSuccessMessage = L10n.presetSaved(preset.name)
            presetErrorMessage = nil
            return true
        } catch ConversionPresetStoreError.emptyName {
            presetSuccessMessage = nil
            presetErrorMessage = L10n.presetNameRequired
            return false
        } catch {
            presetSuccessMessage = nil
            presetErrorMessage = L10n.presetOperationFailed(error.localizedDescription)
            return false
        }
    }

    func applyPreset(_ preset: SavedConversionPreset) {
        presetSuccessMessage = nil
        presetErrorMessage = nil
        if preset.algorithmVersion == PixelCoreInfo.algorithmVersion {
            apply(preset.settings)
            settingsCompatibilityWarning = nil
        } else {
            apply(PixelConversionSettings())
            settingsCompatibilityWarning = L10n.presetVersionFallback(
                preset.name,
                preset.algorithmVersion,
                PixelCoreInfo.algorithmVersion
            )
        }
        refreshProRequirement()
    }

    func deletePreset(_ preset: SavedConversionPreset) async {
        do {
            try await presetStore.deletePreset(id: preset.id)
            savedPresets = try await presetStore.loadPresets()
            presetSuccessMessage = L10n.presetDeleted(preset.name)
            presetErrorMessage = nil
        } catch {
            presetSuccessMessage = nil
            presetErrorMessage = L10n.presetOperationFailed(error.localizedDescription)
        }
    }

    func prepareReviewPresets() {
        let now = Date(timeIntervalSince1970: 1_751_328_000)
        savedPresets = [
            SavedConversionPreset(
                id: UUID(),
                name: L10n.presetReviewSoftPortrait,
                settings: PixelConversionSettings(
                    longSide: 64,
                    upscale: 8,
                    colorMode: .palette(
                        PixelPalette(
                            name: "Candy 8",
                            colors: Self.palettePresets.first(where: { $0.id == "candy-8" })?.colors ?? []
                        ),
                        application: .preserveTone(saturation: 45, lightness: 58)
                    ),
                    outline: PixelOutlineSettings(mode: .adaptive, threshold: 20)
                ),
                algorithmVersion: PixelCoreInfo.algorithmVersion,
                createdAt: now,
                updatedAt: now
            ),
            SavedConversionPreset(
                id: UUID(),
                name: L10n.presetReviewGameSprite,
                settings: PixelConversionSettings(
                    longSide: 48,
                    upscale: 10,
                    colorMode: .palette(
                        PixelPalette(
                            name: "PICO-8",
                            colors: Self.palettePresets.first(where: { $0.id == "pico-8" })?.colors ?? []
                        ),
                        application: .exact
                    ),
                    outline: PixelOutlineSettings(mode: .black, threshold: 15)
                ),
                algorithmVersion: PixelCoreInfo.algorithmVersion,
                createdAt: now.addingTimeInterval(-60),
                updatedAt: now.addingTimeInterval(-60)
            ),
        ]
    }

    func convert(saveMode: ConversionSaveMode) {
        let settings: PixelConversionSettings
        do {
            settings = try makeSettings()
        } catch {
            errorMessage = error.localizedDescription
            state = .failure
            return
        }
        guard ProAccessPolicy.canConvert(settings, entitlement: entitlement.status) else {
            requiresPro = true
            errorMessage = L10n.proRequired
            return
        }

        conversionTask?.cancel()
        loaderTask?.cancel()
        state = .rendering
        showsLoader = false
        requiresPro = false
        errorMessage = nil
        loaderTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, self.state == .rendering else { return }
            self.showsLoader = true
        }

        let sourceData = sourceData
        let sourceFilename = sourceFilename
        let existingID = currentRecord?.id
        conversionTask = Task { [weak self] in
            let outcome = await Task.detached(priority: .userInitiated) {
                do {
                    let processor = try PixelCoreProcessor(imageData: sourceData)
                    return ConversionOutcome.success(try processor.convert(settings))
                } catch {
                    return ConversionOutcome.failure(error.localizedDescription)
                }
            }.value
            guard !Task.isCancelled, let self else { return }
            switch outcome {
            case let .success(result):
                do {
                    let recipe = try StoredRecipe(json: result.recipeJSON)
                    let artifact = GeneratedArtifact(
                        pngData: result.pngData,
                        recipeJSON: result.recipeJSON,
                        metadata: recipe.metadata
                    )
                    let record: GeneratedImageRecord
                    if saveMode == .update, let existingID {
                        record = try await self.store.updateRecord(id: existingID, artifact: artifact)
                    } else {
                        record = try await self.store.createRecord(
                            sourceData: sourceData,
                            sourceFilename: sourceFilename,
                            artifact: artifact
                        )
                    }
                    self.currentRecord = record
                    self.lastRenderedSettings = recipe.settings
                    self.lastRenderedAlgorithmVersion = recipe.metadata.algorithmVersion
                    self.latestPNGData = result.pngData
                    self.outputImage = UIImage(data: result.pngData)
                    self.showsLoader = false
                    self.settingsCompatibilityWarning = nil
                    self.state = .result
                    await self.onLibraryChange()
                } catch {
                    self.fail(error.localizedDescription)
                }
            case let .failure(message):
                self.fail(message)
            }
        }
    }

    func saveOutputToPhotos() async {
        guard photoSaveState != .saving, let pngData = latestPNGData else { return }
        photoSaveState = .saving
        do {
            try await photoLibrarySaver.savePNG(pngData, filename: suggestedOutputName)
            errorMessage = nil
            photoSaveState = .saved
        } catch {
            photoSaveState = .failed(L10n.photoSaveFailure(error.localizedDescription))
        }
    }

    private var suggestedOutputName: String {
        let stem = (sourceFilename as NSString).deletingPathExtension
        return "\(stem)-pixel.png"
    }

    private func makeSettings() throws -> PixelConversionSettings {
        let colorMode: PixelColorMode
        if paletteSelection == .source {
            colorMode = .source
        } else {
            let palette = try selectedPalette()
            let application: PixelPaletteApplication = preservesTone
                ? .preserveTone(
                    saturation: UInt8(clamping: saturation),
                    lightness: UInt8(clamping: lightness)
                )
                : .exact
            colorMode = .palette(palette, application: application)
        }
        return PixelConversionSettings(
            longSide: UInt32(clamping: longSide),
            upscale: UInt32(clamping: upscale),
            crop: .full,
            colorMode: colorMode,
            outline: PixelOutlineSettings(
                mode: outlineMode,
                threshold: UInt8(clamping: outlineThreshold)
            )
        )
    }

    private func selectedPalette() throws -> PixelPalette {
        switch paletteSelection {
        case .source:
            throw ConversionModelError.emptyPalette
        case let .preset(identifier):
            guard let preset = Self.palettePresets.first(where: { $0.id == identifier }) else {
                throw ConversionModelError.emptyPalette
            }
            return PixelPalette(name: preset.name, colors: preset.colors)
        case .custom:
            let colors = customPaletteText
                .split(separator: ",")
                .compactMap { Self.parseHex(String($0)) }
            guard !colors.isEmpty else { throw ConversionModelError.emptyPalette }
            return PixelPalette(name: "Custom", colors: colors)
        }
    }

    private func apply(_ settings: PixelConversionSettings) {
        longSide = Int(settings.longSide)
        upscale = Int(settings.upscale)
        customPaletteText = "#000000, #FFFFFF"
        preservesTone = false
        saturation = 50
        lightness = 50
        switch settings.colorMode {
        case .source:
            paletteSelection = .source
            preservesTone = false
        case let .palette(palette, application):
            if let preset = Self.palettePresets.first(where: {
                $0.name == palette.name && $0.colors == palette.colors
            }) {
                paletteSelection = .preset(preset.id)
            } else {
                paletteSelection = .custom
                customPaletteText = palette.colors.map(Self.hex).joined(separator: ", ")
            }
            switch application {
            case .exact:
                preservesTone = false
            case let .preserveTone(storedSaturation, storedLightness):
                preservesTone = true
                saturation = Int(storedSaturation)
                lightness = Int(storedLightness)
            }
        }
        outlineMode = settings.outline.mode
        outlineThreshold = Int(settings.outline.threshold)
    }

    private func restoreLastRenderedSettings() {
        guard let settings = lastRenderedSettings,
              let storedVersion = lastRenderedAlgorithmVersion
        else {
            settingsCompatibilityWarning = nil
            return
        }
        guard storedVersion == PixelCoreInfo.algorithmVersion else {
            apply(PixelConversionSettings())
            settingsCompatibilityWarning = L10n.recipeVersionFallback(
                storedVersion,
                PixelCoreInfo.algorithmVersion
            )
            return
        }
        apply(settings)
        settingsCompatibilityWarning = nil
    }

    private func fail(_ message: String) {
        showsLoader = false
        errorMessage = message
        state = .failure
    }

    private static func parseHex(_ value: String) -> PixelRGBColor? {
        guard let rgb = parseHexValue(value) else { return nil }
        return PixelRGBColor(
            red: UInt8((rgb >> 16) & 0xFF),
            green: UInt8((rgb >> 8) & 0xFF),
            blue: UInt8(rgb & 0xFF)
        )
    }

    private static func hex(_ color: PixelRGBColor) -> String {
        String(format: "#%02X%02X%02X", color.red, color.green, color.blue)
    }

    private static func parseHexValue(_ value: String) -> UInt32? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard clean.count == 6 else { return nil }
        return UInt32(clean, radix: 16)
    }

    static let palettePresets = [
        PalettePreset(id: "game-boy", name: "Game Boy", colorValues: [
            0x0F380F, 0x306230, 0x8BAC0F, 0x9BBC0F,
        ]),
        PalettePreset(id: "pico-8", name: "PICO-8", colorValues: [
            0x000000, 0x1D2B53, 0x7E2553, 0x008751,
            0xFFF1E8, 0xFF004D, 0xFFA300, 0xFFEC27,
        ]),
        PalettePreset(id: "mono-ink", name: "Mono Ink", colorValues: [
            0x111318, 0x505866, 0xA9B0BA, 0xF5F1E8,
        ]),
        PalettePreset(id: "ocean-8", name: "Ocean 8", colorValues: [
            0x071A2B, 0x0B3C5D, 0x086788, 0x00A6A6,
            0x7FD1B9, 0xD5F2E3, 0xF0C36E, 0xF47E60,
        ]),
        PalettePreset(id: "sunset-8", name: "Sunset 8", colorValues: [
            0x211A3A, 0x51355A, 0x8E3B66, 0xD4515C,
            0xF58A5C, 0xFFC46B, 0xFFE7A0, 0xFFF4D6,
        ]),
        PalettePreset(id: "forest-8", name: "Forest 8", colorValues: [
            0x10231A, 0x214E34, 0x397A4A, 0x61A052,
            0xA1C95A, 0xD4DB72, 0x8A5A3B, 0xE8D8A8,
        ]),
        PalettePreset(id: "candy-8", name: "Candy 8", colorValues: [
            0x2A1B3D, 0x6A2C70, 0xB83B8F, 0xF06F9C,
            0xFFB3C6, 0xFFD6A5, 0xA0E7E5, 0xB4F8C8,
        ]),
        PalettePreset(id: "sepia-6", name: "Sepia 6", colorValues: [
            0x241A14, 0x4D3427, 0x76523A, 0xA47A55, 0xD2AC7B, 0xF1DFC0,
        ]),
    ]
}

enum PhotoSaveState: Equatable {
    case idle
    case saving
    case saved
    case failed(String)
}

@MainActor
protocol PhotoLibrarySaving {
    func savePNG(_ data: Data, filename: String) async throws
}

struct SystemPhotoLibrarySaver: PhotoLibrarySaving {
    func savePNG(_ data: Data, filename: String) async throws {
        guard !data.isEmpty, UIImage(data: data) != nil else {
            throw PhotoLibrarySaveError.invalidImage
        }
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard PhotoLibraryAccessPolicy.canSave(status: authorization) else {
            throw PhotoLibrarySaveError.accessDenied
        }
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pixel-forge-\(UUID().uuidString).png", isDirectory: false)
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try await addPNGToPhotoLibrary(at: temporaryURL, filename: filename)
    }
}

// Photos runs this closure on its private changes queue, so it must not inherit the saver protocol's MainActor.
private func addPNGToPhotoLibrary(at fileURL: URL, filename: String) async throws {
    let options = PHAssetResourceCreationOptions()
    options.originalFilename = filename
    try await PHPhotoLibrary.shared().performChanges {
        let request = PHAssetCreationRequest.forAsset()
        request.addResource(with: .photo, fileURL: fileURL, options: options)
    }
}

enum PhotoLibraryAccessPolicy {
    static func canSave(status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }
}

private enum PhotoLibrarySaveError: LocalizedError {
    case accessDenied
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            L10n.photosAccessDenied
        case .invalidImage:
            L10n.invalidPhotoImage
        }
    }
}

private enum ConversionOutcome: Sendable {
    case success(PixelRenderResult)
    case failure(String)
}

private enum ConversionModelError: LocalizedError {
    case emptyPalette

    var errorDescription: String? {
        L10n.invalidPalette
    }
}
