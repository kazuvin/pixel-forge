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

    init(store: LocalLibraryStore = LocalLibraryStore()) {
        self.store = store
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

enum CropSelection: String, CaseIterable, Identifiable {
    case full
    case rectangle

    var id: Self { self }
}

enum PaletteSelection: String, CaseIterable, Identifiable {
    case source
    case gameBoy
    case pico8
    case custom

    var id: Self { self }
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

    @Published var longSide = 64
    @Published var upscale = 8
    @Published var cropSelection: CropSelection = .full
    @Published var cropX = 0
    @Published var cropY = 0
    @Published var cropWidth = 1
    @Published var cropHeight = 1
    @Published var paletteSelection: PaletteSelection = .source
    @Published var customPaletteText = "#000000, #FFFFFF"
    @Published var preservesTone = false
    @Published var saturation = 50
    @Published var lightness = 50
    @Published var outlineMode: PixelOutlineMode = .none
    @Published var outlineThreshold = 15

    private let store: LocalLibraryStore
    private let entitlement: ProEntitlementService
    private let photoLibrarySaver: any PhotoLibrarySaving
    private let onLibraryChange: @MainActor () async -> Void
    private var latestPNGData: Data?
    private var conversionTask: Task<Void, Never>?
    private var loaderTask: Task<Void, Never>?

    init(
        sourceData: Data,
        sourceFilename: String,
        store: LocalLibraryStore,
        entitlement: ProEntitlementService,
        photoLibrarySaver: any PhotoLibrarySaving = SystemPhotoLibrarySaver(),
        onLibraryChange: @escaping @MainActor () async -> Void
    ) throws {
        let processor = try PixelCoreProcessor(imageData: sourceData)
        self.sourceData = sourceData
        self.sourceFilename = sourceFilename
        sourceImage = UIImage(data: sourceData)
        sourceDimensions = processor.sourceDimensions
        cropWidth = Int(processor.sourceDimensions.width)
        cropHeight = Int(processor.sourceDimensions.height)
        state = .editing
        self.store = store
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
        self.entitlement = entitlement
        self.photoLibrarySaver = photoLibrarySaver
        self.onLibraryChange = onLibraryChange
        apply(recipe.settings)
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

    func edit() {
        errorMessage = nil
        requiresPro = false
        photoSaveState = .idle
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
                    self.latestPNGData = result.pngData
                    self.outputImage = UIImage(data: result.pngData)
                    self.showsLoader = false
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
        let crop: PixelCropRegion
        switch cropSelection {
        case .full:
            crop = .full
        case .rectangle:
            crop = .rectangle(
                PixelCropRect(
                    x: UInt32(max(0, cropX)),
                    y: UInt32(max(0, cropY)),
                    width: UInt32(max(1, cropWidth)),
                    height: UInt32(max(1, cropHeight))
                )
            )
        }

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
            crop: crop,
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
        case .gameBoy:
            return PixelPalette(name: "Game Boy", colors: Self.gameBoyColors)
        case .pico8:
            return PixelPalette(name: "PICO-8", colors: Self.pico8Colors)
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
        switch settings.crop {
        case .full:
            cropSelection = .full
            cropX = 0
            cropY = 0
            cropWidth = Int(sourceDimensions.width)
            cropHeight = Int(sourceDimensions.height)
        case let .rectangle(rect):
            cropSelection = .rectangle
            cropX = Int(rect.x)
            cropY = Int(rect.y)
            cropWidth = Int(rect.width)
            cropHeight = Int(rect.height)
        }
        switch settings.colorMode {
        case .source:
            paletteSelection = .source
            preservesTone = false
        case let .palette(palette, application):
            if palette.name == "Game Boy" {
                paletteSelection = .gameBoy
            } else if palette.name == "PICO-8" {
                paletteSelection = .pico8
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

    private func fail(_ message: String) {
        showsLoader = false
        errorMessage = message
        state = .failure
    }

    private static func parseHex(_ value: String) -> PixelRGBColor? {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard clean.count == 6, let rgb = UInt32(clean, radix: 16) else { return nil }
        return PixelRGBColor(
            red: UInt8((rgb >> 16) & 0xFF),
            green: UInt8((rgb >> 8) & 0xFF),
            blue: UInt8(rgb & 0xFF)
        )
    }

    private static func hex(_ color: PixelRGBColor) -> String {
        String(format: "#%02X%02X%02X", color.red, color.green, color.blue)
    }

    private static let gameBoyColors = [
        PixelRGBColor(red: 15, green: 56, blue: 15),
        PixelRGBColor(red: 48, green: 98, blue: 48),
        PixelRGBColor(red: 139, green: 172, blue: 15),
        PixelRGBColor(red: 155, green: 188, blue: 15),
    ]

    private static let pico8Colors = [
        PixelRGBColor(red: 0, green: 0, blue: 0),
        PixelRGBColor(red: 29, green: 43, blue: 83),
        PixelRGBColor(red: 126, green: 37, blue: 83),
        PixelRGBColor(red: 0, green: 135, blue: 81),
        PixelRGBColor(red: 255, green: 241, blue: 232),
        PixelRGBColor(red: 255, green: 0, blue: 77),
        PixelRGBColor(red: 255, green: 163, blue: 0),
        PixelRGBColor(red: 255, green: 236, blue: 39),
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
        let authorization = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard PhotoLibraryAccessPolicy.canSave(status: authorization) else {
            throw PhotoLibrarySaveError.accessDenied
        }
        let options = PHAssetResourceCreationOptions()
        options.originalFilename = filename
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            request.addResource(with: .photo, data: data, options: options)
        }
    }
}

enum PhotoLibraryAccessPolicy {
    static func canSave(status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }
}

private enum PhotoLibrarySaveError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        L10n.photosAccessDenied
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
