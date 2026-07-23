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
    @Published var actionMessage: String?
    @Published var isSavingRecord = false

    private let store: LocalLibraryStore
    private let presetStore: ConversionPresetStore
    private let photoLibrarySaver: any PhotoLibrarySaving

    init(
        store: LocalLibraryStore = LocalLibraryStore(),
        presetStore: ConversionPresetStore = ConversionPresetStore(),
        photoLibrarySaver: any PhotoLibrarySaving = SystemPhotoLibrarySaver()
    ) {
        self.store = store
        self.presetStore = presetStore
        self.photoLibrarySaver = photoLibrarySaver
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
        actionMessage = nil
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

    func adjust(_ record: GeneratedImageRecord, entitlement: ProEntitlementService) async {
        await open(record, entitlement: entitlement)
        session?.edit()
    }

    func saveToPhotos(_ record: GeneratedImageRecord) async {
        guard !isSavingRecord else { return }
        isSavingRecord = true
        defer { isSavingRecord = false }
        do {
            let data = try await store.pngData(for: record)
            try await photoLibrarySaver.savePNG(data, filename: Self.outputName(for: record.sourceFilename))
            errorMessage = nil
            actionMessage = L10n.photoSaveSuccess
        } catch {
            actionMessage = nil
            errorMessage = L10n.photoSaveFailure(error.localizedDescription)
        }
    }

    func duplicate(_ record: GeneratedImageRecord) async {
        do {
            _ = try await store.duplicateRecord(id: record.id)
            await loadLibrary()
            errorMessage = nil
            actionMessage = L10n.duplicateSuccess
        } catch {
            actionMessage = nil
            errorMessage = L10n.duplicateFailure(error.localizedDescription)
        }
    }

    private static func outputName(for sourceFilename: String) -> String {
        let stem = (sourceFilename as NSString).deletingPathExtension
        return "\(stem)-pixel.png"
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
    let colorFamilies: [[UInt32]]

    init(id: String, name: String, colorFamilies: [[UInt32]]) {
        precondition((1 ... 2).contains(colorFamilies.count))
        precondition(colorFamilies.allSatisfy { $0.count == 6 })
        self.id = id
        self.name = name
        self.colorFamilies = colorFamilies
    }

    var colorValues: [UInt32] {
        colorFamilies.flatMap { $0 }
    }

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
        case "arctic-rose": L10n.palettePresetArcticRose
        case "ember-teal": L10n.palettePresetEmberTeal
        case "lavender-lime": L10n.palettePresetLavenderLime
        case "midnight-gold": L10n.palettePresetMidnightGold
        case "sakura-ink": L10n.palettePresetSakuraInk
        case "cyber-violet": L10n.palettePresetCyberViolet
        case "desert-night": L10n.palettePresetDesertNight
        case "crimson-ice": L10n.palettePresetCrimsonIce
        case "lagoon-coral": L10n.palettePresetLagoonCoral
        case "plum-moss": L10n.palettePresetPlumMoss
        case "copper-sky": L10n.palettePresetCopperSky
        case "lemon-grape": L10n.palettePresetLemonGrape
        case "ruby-jade": L10n.palettePresetRubyJade
        case "peach-slate": L10n.palettePresetPeachSlate
        case "aurora": L10n.palettePresetAurora
        case "cloudberry": L10n.palettePresetCloudberry
        default: name
        }
    }
}

struct ConversionStylePreset: Identifiable, Hashable {
    let id: String
    let settings: PixelConversionSettings

    var displayName: String {
        switch id {
        case "standard": L10n.conversionStyleStandard
        case "chunky": L10n.conversionStyleChunky
        case "fine": L10n.conversionStyleFine
        case "game-sprite": L10n.conversionStyleGameSprite
        case "soft-portrait": L10n.conversionStyleSoftPortrait
        case "mono-ink": L10n.conversionStyleMonoInk
        default: id
        }
    }

    var displayDetail: String {
        switch id {
        case "standard": L10n.conversionStyleStandardDetail
        case "chunky": L10n.conversionStyleChunkyDetail
        case "fine": L10n.conversionStyleFineDetail
        case "game-sprite": L10n.conversionStyleGameSpriteDetail
        case "soft-portrait": L10n.conversionStyleSoftPortraitDetail
        case "mono-ink": L10n.conversionStyleMonoInkDetail
        default: ""
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
    @Published private(set) var isPreviewRendering = false
    @Published var outputImage: UIImage?
    @Published var errorMessage: String?
    @Published var previewErrorMessage: String?
    @Published var requiresPro = false
    @Published var currentRecord: GeneratedImageRecord?
    @Published var photoSaveState: PhotoSaveState = .idle
    @Published var duplicateMessage: String?
    @Published var settingsCompatibilityWarning: String?
    @Published private(set) var savedPresets: [SavedConversionPreset] = []
    @Published var presetSuccessMessage: String?
    @Published var presetErrorMessage: String?

    @Published var longSide = 64
    @Published var upscale = 8
    @Published var paletteSelection: PaletteSelection = .source
    @Published var customPaletteColorValues: [UInt32] = [0x000000, 0xFFFFFF]
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
    private let previewRenderer = ConversionPreviewRenderer()
    private var latestPNGData: Data?
    private var previewPNGData: Data?
    private var previewMetadata: GeneratedImageMetadata?
    private var lastRenderedSettings: PixelConversionSettings?
    private var lastRenderedAlgorithmVersion: String?
    private var lastRenderedPresetReference: ConversionPresetReference?
    private var preferredPresetReference: ConversionPresetReference? = .builtIn("standard")
    private var conversionTask: Task<Void, Never>?
    private var loaderTask: Task<Void, Never>?
    private var previewTask: Task<Void, Never>?
    private var previewRevision = 0

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
        previewPNGData = pngData
        previewMetadata = record.metadata
        currentRecord = record
        latestPNGData = pngData
        self.store = store
        self.presetStore = presetStore
        self.entitlement = entitlement
        self.photoLibrarySaver = photoLibrarySaver
        self.onLibraryChange = onLibraryChange
        lastRenderedSettings = recipe.settings
        lastRenderedAlgorithmVersion = recipe.metadata.algorithmVersion
        lastRenderedPresetReference = record.presetReference
        preferredPresetReference = record.presetReference
        if recipe.metadata.algorithmVersion == PixelCoreInfo.algorithmVersion {
            apply(recipe.settings)
        }
    }

    deinit {
        conversionTask?.cancel()
        loaderTask?.cancel()
        previewTask?.cancel()
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
        guard let metadata = displayedMetadata else { return "—" }
        return "\(metadata.outputWidth) × \(metadata.outputHeight) px"
    }

    var logicalDimensionsLabel: String {
        guard let metadata = displayedMetadata else { return "—" }
        return "\(metadata.logicalWidth) × \(metadata.logicalHeight) px"
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

    var selectedConversionStyleTitle: String {
        guard let reference = currentPresetReference() else { return L10n.conversionStyleCustom }
        switch reference.kind {
        case .builtIn:
            return Self.conversionStylePresets
                .first(where: { $0.id == reference.identifier })?.displayName
                ?? L10n.conversionStyleCustom
        case .saved:
            return reference.savedIdentifier
                .flatMap { identifier in savedPresets.first(where: { $0.id == identifier })?.name }
                ?? L10n.conversionStyleCustom
        }
    }

    var selectedConversionStyleDetail: String {
        guard let settings = try? makeSettings() else { return L10n.invalidPalette }
        return settingsSummary(settings)
    }

    var selectedConversionStyleColorValues: [UInt32] {
        guard let settings = try? makeSettings() else { return [] }
        return colorValues(for: settings)
    }

    var currentStyleIsCustom: Bool {
        currentPresetReference() == nil
    }

    func isConversionStyleSelected(_ preset: ConversionStylePreset) -> Bool {
        currentPresetReference() == .builtIn(preset.id)
    }

    func isSavedPresetSelected(_ preset: SavedConversionPreset) -> Bool {
        currentPresetReference() == .saved(preset.id)
    }

    func conversionStyleRequiresPro(_ preset: ConversionStylePreset) -> Bool {
        !ProAccessPolicy.requiredFeatures(for: preset.settings).isEmpty
    }

    func savedPresetRequiresPro(_ preset: SavedConversionPreset) -> Bool {
        !ProAccessPolicy.requiredFeatures(for: preset.settings).isEmpty
    }

    func applyConversionStyle(_ preset: ConversionStylePreset) {
        apply(preset.settings)
        preferredPresetReference = .builtIn(preset.id)
        settingsCompatibilityWarning = nil
        settingsDidChange()
    }

    func settingsSummary(_ settings: PixelConversionSettings) -> String {
        L10n.presetSummary(
            Int(settings.longSide),
            Int(settings.upscale),
            paletteTitle(for: settings)
        )
    }

    func paletteTitle(for settings: PixelConversionSettings) -> String {
        switch settings.colorMode {
        case .source:
            L10n.paletteSource
        case let .palette(palette, _):
            Self.palettePresets
                .first(where: { $0.name == palette.name && $0.colors == palette.colors })?
                .displayName ?? palette.name
        }
    }

    func colorValues(for settings: PixelConversionSettings) -> [UInt32] {
        guard case let .palette(palette, _) = settings.colorMode else { return [] }
        return palette.colors.map(Self.colorValue)
    }

    func edit() {
        errorMessage = nil
        duplicateMessage = nil
        requiresPro = false
        photoSaveState = .idle
        restoreLastRenderedSettings()
        state = .editing
        settingsDidChange()
    }

    func retry() {
        state = .editing
        refreshPreview()
    }

    func refreshProRequirement() {
        guard !entitlement.status.isActive, let settings = try? makeSettings() else {
            requiresPro = false
            return
        }
        requiresPro = !ProAccessPolicy.requiredFeatures(for: settings).isEmpty
    }

    func settingsDidChange() {
        photoSaveState = .idle
        refreshProRequirement()
        refreshPreview()
    }

    func refreshPreview(immediately: Bool = false) {
        guard state == .editing else { return }
        let settings: PixelConversionSettings
        do {
            settings = try makeSettings()
        } catch {
            previewTask?.cancel()
            isPreviewRendering = false
            previewErrorMessage = error.localizedDescription
            return
        }

        previewTask?.cancel()
        previewRevision += 1
        let revision = previewRevision
        let sourceData = sourceData
        isPreviewRendering = true
        previewErrorMessage = nil
        previewTask = Task { [weak self] in
            if !immediately {
                do {
                    try await Task.sleep(for: .milliseconds(120))
                } catch {
                    return
                }
            }
            let outcome = await self?.previewRenderer.render(
                sourceData: sourceData,
                settings: settings
            )
            guard
                !Task.isCancelled,
                let self,
                let outcome,
                revision == self.previewRevision
            else { return }
            self.isPreviewRendering = false
            switch outcome {
            case let .success(result):
                do {
                    let recipe = try StoredRecipe(json: result.recipeJSON)
                    self.previewPNGData = result.pngData
                    self.previewMetadata = recipe.metadata
                    self.outputImage = UIImage(data: result.pngData)
                    self.previewErrorMessage = nil
                } catch {
                    self.previewErrorMessage = error.localizedDescription
                }
            case let .failure(message):
                self.previewErrorMessage = message
            }
        }
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
            preferredPresetReference = .saved(preset.id)
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
            preferredPresetReference = .saved(preset.id)
            settingsCompatibilityWarning = nil
        } else {
            apply(PixelConversionSettings())
            preferredPresetReference = .builtIn("standard")
            settingsCompatibilityWarning = L10n.presetVersionFallback(
                preset.name,
                preset.algorithmVersion,
                PixelCoreInfo.algorithmVersion
            )
        }
        settingsDidChange()
    }

    func deletePreset(_ preset: SavedConversionPreset) async {
        do {
            try await presetStore.deletePreset(id: preset.id)
            if preferredPresetReference == .saved(preset.id) {
                preferredPresetReference = nil
            }
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
                settings: Self.conversionStylePresets
                    .first(where: { $0.id == "soft-portrait" })?.settings ?? PixelConversionSettings(),
                algorithmVersion: PixelCoreInfo.algorithmVersion,
                createdAt: now,
                updatedAt: now
            ),
            SavedConversionPreset(
                id: UUID(),
                name: L10n.presetReviewGameSprite,
                settings: Self.conversionStylePresets
                    .first(where: { $0.id == "game-sprite" })?.settings ?? PixelConversionSettings(),
                algorithmVersion: PixelCoreInfo.algorithmVersion,
                createdAt: now.addingTimeInterval(-60),
                updatedAt: now.addingTimeInterval(-60)
            ),
        ]
    }

    func prepareReviewPresetNotifications() {
        savedPresets = []
        presetSuccessMessage = L10n.presetDeleted("TEST")
        presetErrorMessage = L10n.presetNameRequired
    }

    func convert(saveMode: ConversionSaveMode) {
        let settings: PixelConversionSettings
        do {
            settings = try makeSettings()
        } catch {
            state = .failure
            errorMessage = error.localizedDescription
            return
        }
        guard ProAccessPolicy.canConvert(settings, entitlement: entitlement.status) else {
            requiresPro = true
            errorMessage = nil
            return
        }

        conversionTask?.cancel()
        loaderTask?.cancel()
        previewTask?.cancel()
        previewRevision += 1
        state = .rendering
        showsLoader = false
        isPreviewRendering = false
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
        let presetReference = currentPresetReference(for: settings)
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
                        metadata: recipe.metadata,
                        presetReference: presetReference
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
                    self.lastRenderedPresetReference = record.presetReference
                    self.preferredPresetReference = record.presetReference
                    self.latestPNGData = result.pngData
                    self.previewPNGData = result.pngData
                    self.previewMetadata = recipe.metadata
                    self.outputImage = UIImage(data: result.pngData)
                    self.showsLoader = false
                    self.previewErrorMessage = nil
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
        guard photoSaveState != .saving, let pngData = currentOutputPNGData else { return }
        photoSaveState = .saving
        do {
            try await photoLibrarySaver.savePNG(pngData, filename: suggestedOutputName)
            errorMessage = nil
            photoSaveState = .saved
        } catch {
            photoSaveState = .failed(L10n.photoSaveFailure(error.localizedDescription))
        }
    }

    func duplicateCurrentRecord() async {
        guard let currentRecord else { return }
        do {
            _ = try await store.duplicateRecord(id: currentRecord.id)
            await onLibraryChange()
            errorMessage = nil
            duplicateMessage = L10n.duplicateSuccess
        } catch {
            duplicateMessage = nil
            errorMessage = L10n.duplicateFailure(error.localizedDescription)
        }
    }

    @discardableResult
    func deleteCurrentRecord() async -> Bool {
        guard let currentRecord else { return false }
        do {
            try await store.deleteRecord(id: currentRecord.id)
            await onLibraryChange()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private var suggestedOutputName: String {
        let stem = (sourceFilename as NSString).deletingPathExtension
        return "\(stem)-pixel.png"
    }

    private var displayedMetadata: GeneratedImageMetadata? {
        if state == .editing {
            return previewMetadata ?? currentRecord?.metadata
        }
        return currentRecord?.metadata ?? previewMetadata
    }

    private var currentOutputPNGData: Data? {
        if state == .editing {
            return previewPNGData ?? latestPNGData
        }
        return latestPNGData ?? previewPNGData
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
            let colors = customPaletteColorValues.map(Self.rgbColor)
            guard !colors.isEmpty else { throw ConversionModelError.emptyPalette }
            return PixelPalette(name: "Custom", colors: colors)
        }
    }

    private func apply(_ settings: PixelConversionSettings) {
        longSide = Int(settings.longSide)
        upscale = Int(settings.upscale)
        customPaletteColorValues = [0x000000, 0xFFFFFF]
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
                customPaletteColorValues = palette.colors.map(Self.colorValue)
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
            preferredPresetReference = .builtIn("standard")
            settingsCompatibilityWarning = L10n.recipeVersionFallback(
                storedVersion,
                PixelCoreInfo.algorithmVersion
            )
            return
        }
        apply(settings)
        preferredPresetReference = lastRenderedPresetReference
        settingsCompatibilityWarning = nil
    }

    private func currentPresetReference() -> ConversionPresetReference? {
        guard let settings = try? makeSettings() else { return nil }
        return currentPresetReference(for: settings)
    }

    private func currentPresetReference(
        for settings: PixelConversionSettings
    ) -> ConversionPresetReference? {
        if let preferredPresetReference,
           self.settings(for: preferredPresetReference).map({
               Self.editorSettingsEqual($0, settings)
           }) == true
        {
            return preferredPresetReference
        }
        if let builtIn = Self.conversionStylePresets.first(where: {
            Self.editorSettingsEqual($0.settings, settings)
        }) {
            return .builtIn(builtIn.id)
        }
        if let saved = savedPresets.first(where: {
            $0.algorithmVersion == PixelCoreInfo.algorithmVersion
                && Self.editorSettingsEqual($0.settings, settings)
        }) {
            return .saved(saved.id)
        }
        return nil
    }

    private func settings(
        for reference: ConversionPresetReference
    ) -> PixelConversionSettings? {
        switch reference.kind {
        case .builtIn:
            Self.conversionStylePresets
                .first(where: { $0.id == reference.identifier })?.settings
        case .saved:
            reference.savedIdentifier.flatMap { identifier in
                savedPresets.first(where: {
                    $0.id == identifier && $0.algorithmVersion == PixelCoreInfo.algorithmVersion
                })?.settings
            }
        }
    }

    private func fail(_ message: String) {
        showsLoader = false
        state = .failure
        errorMessage = message
    }

    private static func rgbColor(_ value: UInt32) -> PixelRGBColor {
        return PixelRGBColor(
            red: UInt8((value >> 16) & 0xFF),
            green: UInt8((value >> 8) & 0xFF),
            blue: UInt8(value & 0xFF)
        )
    }

    private static func colorValue(_ color: PixelRGBColor) -> UInt32 {
        UInt32(color.red) << 16 | UInt32(color.green) << 8 | UInt32(color.blue)
    }

    private static func editorSettingsEqual(
        _ lhs: PixelConversionSettings,
        _ rhs: PixelConversionSettings
    ) -> Bool {
        guard lhs.longSide == rhs.longSide,
              lhs.upscale == rhs.upscale,
              lhs.crop == rhs.crop,
              lhs.outline == rhs.outline
        else {
            return false
        }
        switch (lhs.colorMode, rhs.colorMode) {
        case (.source, .source):
            return true
        case let (.palette(lhsPalette, lhsApplication), .palette(rhsPalette, rhsApplication)):
            return lhsPalette.colors == rhsPalette.colors && lhsApplication == rhsApplication
        default:
            return false
        }
    }

    nonisolated static let palettePresets = [
        PalettePreset(id: "game-boy", name: "Game Boy", colorFamilies: [[
            0x081C0C, 0x0F380F, 0x306230, 0x5A7D25, 0x8BAC0F, 0xC7D86D,
        ]]),
        PalettePreset(id: "pico-8", name: "PICO Spectrum", colorFamilies: [
            [
                0x000000, 0x1D2B53, 0x005F73, 0x008751, 0x29ADFF, 0xC2FFED,
            ],
            [
                0x3B102D, 0x7E2553, 0xAB5236, 0xFF004D, 0xFFA300, 0xFFEC27,
            ],
        ]),
        PalettePreset(id: "mono-ink", name: "Mono Ink", colorFamilies: [[
            0x111318, 0x303640, 0x505866, 0x7B8491, 0xA9B0BA, 0xF5F1E8,
        ]]),
        PalettePreset(id: "ocean-8", name: "Ocean & Coral", colorFamilies: [
            [
                0x071A2B, 0x0B3C5D, 0x086788, 0x00A6A6, 0x7FD1B9, 0xD5F2E3,
            ],
            [
                0x3A1E2A, 0x7C3F58, 0xC95C68, 0xF47E60, 0xF0C36E, 0xFFF0C2,
            ],
        ]),
        PalettePreset(id: "sunset-8", name: "Violet Sunset", colorFamilies: [
            [
                0x211A3A, 0x51355A, 0x713C68, 0x8E3B66, 0xB84A73, 0xE58BA3,
            ],
            [
                0x5A2A24, 0x8E4632, 0xD4515C, 0xF58A5C, 0xFFC46B, 0xFFF4D6,
            ],
        ]),
        PalettePreset(id: "forest-8", name: "Forest & Clay", colorFamilies: [
            [
                0x10231A, 0x214E34, 0x397A4A, 0x61A052, 0xA1C95A, 0xD4DB72,
            ],
            [
                0x2A1A16, 0x513326, 0x7A4C34, 0x8A5A3B, 0xB8845C, 0xE8D8A8,
            ],
        ]),
        PalettePreset(id: "candy-8", name: "Berry & Mint", colorFamilies: [
            [
                0x2A1B3D, 0x6A2C70, 0xB83B8F, 0xF06F9C, 0xFFB3C6, 0xFFE0EA,
            ],
            [
                0x14363D, 0x28706F, 0x45A6A1, 0x7AD6CF, 0xA0E7E5, 0xB4F8C8,
            ],
        ]),
        PalettePreset(id: "sepia-6", name: "Sepia", colorFamilies: [[
            0x241A14, 0x4D3427, 0x76523A, 0xA47A55, 0xD2AC7B, 0xF1DFC0,
        ]]),
        PalettePreset(id: "arctic-rose", name: "Arctic Rose", colorFamilies: [
            [
                0x081A33, 0x123B66, 0x1E6091, 0x3185B8, 0x6CB7D9, 0xB9E7F2,
            ],
            [
                0x3A1630, 0x6E2850, 0xA94470, 0xD86C92, 0xF2A2BB, 0xFFD5E2,
            ],
        ]),
        PalettePreset(id: "ember-teal", name: "Ember Teal", colorFamilies: [
            [
                0x062B2A, 0x0D4A47, 0x14746F, 0x1B9C91, 0x63C7B8, 0xB9EEE3,
            ],
            [
                0x3B1710, 0x6D2B1A, 0xA84724, 0xD86432, 0xF29A57, 0xFFD2A3,
            ],
        ]),
        PalettePreset(id: "lavender-lime", name: "Lavender Lime", colorFamilies: [
            [
                0x211635, 0x44265E, 0x6B3D88, 0x945EB2, 0xC18AD4, 0xE6C5F0,
            ],
            [
                0x1B2A12, 0x36531C, 0x5B7F27, 0x87AB36, 0xB8D85A, 0xE5F29A,
            ],
        ]),
        PalettePreset(id: "midnight-gold", name: "Midnight Gold", colorFamilies: [
            [
                0x050D1C, 0x0B1D38, 0x12345C, 0x1E5682, 0x4B7FA8, 0x9CC4DE,
            ],
            [
                0x33220A, 0x61400F, 0x956315, 0xC48C23, 0xE5B84A, 0xFFE49A,
            ],
        ]),
        PalettePreset(id: "sakura-ink", name: "Sakura Ink", colorFamilies: [
            [
                0x331623, 0x65243E, 0x9B365C, 0xCF5B7C, 0xF08EAA, 0xFFD0DD,
            ],
            [
                0x10141B, 0x262C36, 0x47515F, 0x6F7B89, 0xA6AFB8, 0xE8E5DF,
            ],
        ]),
        PalettePreset(id: "cyber-violet", name: "Cyber Violet", colorFamilies: [
            [
                0x031F2B, 0x063E50, 0x096478, 0x0A8CA0, 0x45BCD0, 0xA6ECF2,
            ],
            [
                0x1C1233, 0x382258, 0x5A3482, 0x8250AE, 0xB080D0, 0xE0C4F0,
            ],
        ]),
        PalettePreset(id: "desert-night", name: "Desert Night", colorFamilies: [
            [
                0x342515, 0x654627, 0x947043, 0xC39B66, 0xE4C28F, 0xF7E4BC,
            ],
            [
                0x10142E, 0x202657, 0x343B80, 0x525BA8, 0x8189CB, 0xC4C8EA,
            ],
        ]),
        PalettePreset(id: "crimson-ice", name: "Crimson Ice", colorFamilies: [
            [
                0x320E16, 0x621723, 0x982433, 0xC53A4C, 0xE86B78, 0xF8B5BC,
            ],
            [
                0x0B2633, 0x16495F, 0x24748D, 0x3FA4B8, 0x82D1DA, 0xD5F4F2,
            ],
        ]),
        PalettePreset(id: "lagoon-coral", name: "Lagoon Coral", colorFamilies: [
            [
                0x042A33, 0x07515E, 0x0A7A87, 0x12A4AC, 0x62CDD0, 0xB8F0E9,
            ],
            [
                0x3B1820, 0x702B34, 0xA9444D, 0xD96368, 0xF29A91, 0xFFD1BD,
            ],
        ]),
        PalettePreset(id: "plum-moss", name: "Plum Moss", colorFamilies: [
            [
                0x2B142A, 0x522146, 0x7D315F, 0xA84D7A, 0xD17C9F, 0xF0BDD2,
            ],
            [
                0x182418, 0x31462A, 0x506A3D, 0x78934F, 0xA7BC70, 0xDCE0A0,
            ],
        ]),
        PalettePreset(id: "copper-sky", name: "Copper Sky", colorFamilies: [
            [
                0x32170D, 0x64301A, 0x964B26, 0xC36B39, 0xE69A65, 0xF4C9A2,
            ],
            [
                0x0A2440, 0x17466B, 0x286E96, 0x4B98BE, 0x8BC9E1, 0xD2EEF6,
            ],
        ]),
        PalettePreset(id: "lemon-grape", name: "Lemon Grape", colorFamilies: [
            [
                0x332C08, 0x665A0D, 0x988A15, 0xC7B52B, 0xE9D85B, 0xFFF2A6,
            ],
            [
                0x251438, 0x4A2468, 0x713893, 0x9B5ABE, 0xC98CDB, 0xEACAF2,
            ],
        ]),
        PalettePreset(id: "ruby-jade", name: "Ruby Jade", colorFamilies: [
            [
                0x350D1E, 0x68142F, 0x9D2347, 0xCC3E62, 0xEC7590, 0xF7B8C7,
            ],
            [
                0x06291F, 0x0D513C, 0x18795A, 0x2AA379, 0x70C7A1, 0xBCE8D1,
            ],
        ]),
        PalettePreset(id: "peach-slate", name: "Peach Slate", colorFamilies: [
            [
                0x3A201B, 0x714035, 0xA96350, 0xD5856E, 0xF1B09A, 0xFFE0CF,
            ],
            [
                0x151D29, 0x2D3A4A, 0x4B5C6F, 0x71869A, 0xA4B3C1, 0xDCE2E7,
            ],
        ]),
        PalettePreset(id: "aurora", name: "Aurora", colorFamilies: [
            [
                0x032A2F, 0x07545B, 0x0C7E84, 0x16A8AA, 0x61D0C9, 0xB8EFE2,
            ],
            [
                0x32132F, 0x621F5A, 0x963080, 0xC84C9F, 0xE87DBB, 0xF7BEDA,
            ],
        ]),
        PalettePreset(id: "cloudberry", name: "Cloudberry", colorFamilies: [
            [
                0x131C2B, 0x2A3A52, 0x455A76, 0x657B98, 0x94A7BD, 0xD4DDE7,
            ],
            [
                0x351328, 0x69213F, 0x9E365B, 0xCB587A, 0xE88FA3, 0xF7C7D2,
            ],
        ]),
    ]

    nonisolated static let conversionStylePresets: [ConversionStylePreset] = {
        func palette(_ identifier: String) -> PixelPalette {
            let preset = palettePresets.first(where: { $0.id == identifier })
            return PixelPalette(name: preset?.name ?? identifier, colors: preset?.colors ?? [])
        }

        return [
            ConversionStylePreset(
                id: "standard",
                settings: PixelConversionSettings()
            ),
            ConversionStylePreset(
                id: "chunky",
                settings: PixelConversionSettings(longSide: 32, upscale: 8)
            ),
            ConversionStylePreset(
                id: "fine",
                settings: PixelConversionSettings(longSide: 128, upscale: 8)
            ),
            ConversionStylePreset(
                id: "game-sprite",
                settings: PixelConversionSettings(
                    longSide: 48,
                    upscale: 10,
                    colorMode: .palette(palette("pico-8"), application: .exact),
                    outline: PixelOutlineSettings(mode: .black, threshold: 15)
                )
            ),
            ConversionStylePreset(
                id: "soft-portrait",
                settings: PixelConversionSettings(
                    longSide: 64,
                    upscale: 8,
                    colorMode: .palette(
                        palette("candy-8"),
                        application: .preserveTone(saturation: 45, lightness: 58)
                    ),
                    outline: PixelOutlineSettings(mode: .adaptive, threshold: 20)
                )
            ),
            ConversionStylePreset(
                id: "mono-ink",
                settings: PixelConversionSettings(
                    longSide: 64,
                    upscale: 8,
                    colorMode: .palette(palette("mono-ink"), application: .exact),
                    outline: PixelOutlineSettings(mode: .black, threshold: 18)
                )
            ),
        ]
    }()
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

private actor ConversionPreviewRenderer {
    func render(
        sourceData: Data,
        settings: PixelConversionSettings
    ) -> ConversionOutcome {
        guard !Task.isCancelled else {
            return .failure(CancellationError().localizedDescription)
        }
        do {
            let processor = try PixelCoreProcessor(imageData: sourceData)
            return .success(try processor.convert(settings))
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}

private enum ConversionModelError: LocalizedError {
    case emptyPalette

    var errorDescription: String? {
        L10n.invalidPalette
    }
}
