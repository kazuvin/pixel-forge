import CryptoKit
import Foundation
import PixelCoreKit

struct SourceAsset: Codable, Equatable, Identifiable, Sendable {
    var id: String { hash }

    let hash: String
    let relativePath: String
    let originalFilename: String
    let byteCount: Int
    let createdAt: Date
}

struct GeneratedImageMetadata: Codable, Equatable, Sendable {
    let logicalWidth: UInt32
    let logicalHeight: UInt32
    let outputWidth: UInt32
    let outputHeight: UInt32
    let paletteName: String?
    let algorithmVersion: String
}

struct GeneratedImageRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let sourceHash: String
    let sourceFilename: String
    let pngRelativePath: String
    let recipeRelativePath: String
    let createdAt: Date
    let updatedAt: Date
    let metadata: GeneratedImageMetadata
}

struct GeneratedArtifact: Equatable, Sendable {
    let pngData: Data
    let recipeJSON: String
    let metadata: GeneratedImageMetadata
}

struct LibrarySnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    var sources: [SourceAsset] = []
    var records: [GeneratedImageRecord] = []
}

enum LocalLibraryError: Error, Equatable {
    case invalidPNG
    case invalidRecipe
    case recordNotFound
    case sourceNotFound
    case unsupportedSchema(Int)
}

actor LocalLibraryStore {
    private let rootURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(rootURL: URL = LocalLibraryStore.defaultRootURL(), fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    static func defaultRootURL(fileManager: FileManager = .default) -> URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return support.appendingPathComponent("PixelForge/Library", isDirectory: true)
    }

    func loadSnapshot() throws -> LibrarySnapshot {
        let manifestURL = rootURL.appendingPathComponent("library.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return LibrarySnapshot()
        }
        let snapshot = try decoder.decode(LibrarySnapshot.self, from: Data(contentsOf: manifestURL))
        guard snapshot.schemaVersion == LibrarySnapshot.currentSchemaVersion else {
            throw LocalLibraryError.unsupportedSchema(snapshot.schemaVersion)
        }
        return snapshot
    }

    func createRecord(
        sourceData: Data,
        sourceFilename: String,
        artifact: GeneratedArtifact,
        now: Date = Date()
    ) throws -> GeneratedImageRecord {
        try validate(artifact)
        try prepareDirectories()

        var snapshot = try loadSnapshot()
        let hash = Self.sha256(sourceData)
        let source = snapshot.sources.first(where: { $0.hash == hash })
            ?? makeSource(hash: hash, data: sourceData, filename: sourceFilename, now: now)
        let sourceWasCreated = !snapshot.sources.contains(where: { $0.hash == hash })
        if sourceWasCreated {
            try sourceData.write(to: url(for: source.relativePath), options: .atomic)
            snapshot.sources.append(source)
        }

        let id = UUID()
        let revision = UUID()
        let paths: ArtifactPaths
        do {
            paths = try writeArtifact(artifact, recordID: id, revision: revision)
            let record = GeneratedImageRecord(
                id: id,
                sourceHash: hash,
                sourceFilename: sourceFilename,
                pngRelativePath: paths.png,
                recipeRelativePath: paths.recipe,
                createdAt: now,
                updatedAt: now,
                metadata: artifact.metadata
            )
            snapshot.records.append(record)
            try save(snapshot)
            return record
        } catch {
            try? fileManager.removeItem(at: revisionURL(recordID: id, revision: revision))
            if sourceWasCreated {
                try? fileManager.removeItem(at: url(for: source.relativePath))
            }
            throw error
        }
    }

    func updateRecord(
        id: UUID,
        artifact: GeneratedArtifact,
        now: Date = Date()
    ) throws -> GeneratedImageRecord {
        try validate(artifact)
        try prepareDirectories()
        var snapshot = try loadSnapshot()
        guard let index = snapshot.records.firstIndex(where: { $0.id == id }) else {
            throw LocalLibraryError.recordNotFound
        }

        let oldRecord = snapshot.records[index]
        let revision = UUID()
        let paths = try writeArtifact(artifact, recordID: id, revision: revision)
        let updated = GeneratedImageRecord(
            id: oldRecord.id,
            sourceHash: oldRecord.sourceHash,
            sourceFilename: oldRecord.sourceFilename,
            pngRelativePath: paths.png,
            recipeRelativePath: paths.recipe,
            createdAt: oldRecord.createdAt,
            updatedAt: now,
            metadata: artifact.metadata
        )
        snapshot.records[index] = updated

        do {
            try save(snapshot)
            let oldRevisionURL = url(for: oldRecord.pngRelativePath).deletingLastPathComponent()
            try? fileManager.removeItem(at: oldRevisionURL)
            return updated
        } catch {
            try? fileManager.removeItem(at: revisionURL(recordID: id, revision: revision))
            throw error
        }
    }

    func deleteRecord(id: UUID) throws {
        var snapshot = try loadSnapshot()
        guard let index = snapshot.records.firstIndex(where: { $0.id == id }) else {
            throw LocalLibraryError.recordNotFound
        }
        let record = snapshot.records.remove(at: index)
        let sourceIsUnreferenced = !snapshot.records.contains { $0.sourceHash == record.sourceHash }
        let source = snapshot.sources.first { $0.hash == record.sourceHash }
        if sourceIsUnreferenced {
            snapshot.sources.removeAll { $0.hash == record.sourceHash }
        }

        try save(snapshot)
        try? fileManager.removeItem(at: recordURL(id: record.id))
        if sourceIsUnreferenced, let source {
            try? fileManager.removeItem(at: url(for: source.relativePath))
        }
    }

    func pngData(for record: GeneratedImageRecord) throws -> Data {
        try Data(contentsOf: url(for: record.pngRelativePath))
    }

    func recipeJSON(for record: GeneratedImageRecord) throws -> String {
        try String(contentsOf: url(for: record.recipeRelativePath), encoding: .utf8)
    }

    func sourceData(for record: GeneratedImageRecord) throws -> Data {
        let snapshot = try loadSnapshot()
        guard let source = snapshot.sources.first(where: { $0.hash == record.sourceHash }) else {
            throw LocalLibraryError.sourceNotFound
        }
        return try Data(contentsOf: url(for: source.relativePath))
    }

    private func prepareDirectories() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: rootURL.appendingPathComponent("sources", isDirectory: true),
            withIntermediateDirectories: true
        )
        try fileManager.createDirectory(
            at: rootURL.appendingPathComponent("records", isDirectory: true),
            withIntermediateDirectories: true
        )
    }

    private func makeSource(hash: String, data: Data, filename: String, now: Date) -> SourceAsset {
        let rawExtension = (filename as NSString).pathExtension.lowercased()
        let safeExtension = rawExtension.allSatisfy { $0.isLetter || $0.isNumber }
            ? rawExtension
            : ""
        let storedName = safeExtension.isEmpty ? hash : "\(hash).\(safeExtension)"
        return SourceAsset(
            hash: hash,
            relativePath: "sources/\(storedName)",
            originalFilename: filename,
            byteCount: data.count,
            createdAt: now
        )
    }

    private func writeArtifact(
        _ artifact: GeneratedArtifact,
        recordID: UUID,
        revision: UUID
    ) throws -> ArtifactPaths {
        let revisionURL = revisionURL(recordID: recordID, revision: revision)
        try fileManager.createDirectory(at: revisionURL, withIntermediateDirectories: true)
        let pngURL = revisionURL.appendingPathComponent("output.png")
        let recipeURL = revisionURL.appendingPathComponent("recipe.json")
        try artifact.pngData.write(to: pngURL, options: .atomic)
        try artifact.recipeJSON.write(to: recipeURL, atomically: true, encoding: .utf8)
        let base = "records/\(recordID.uuidString)/\(revision.uuidString)"
        return ArtifactPaths(png: "\(base)/output.png", recipe: "\(base)/recipe.json")
    }

    private func save(_ snapshot: LibrarySnapshot) throws {
        try prepareDirectories()
        let data = try encoder.encode(snapshot)
        try data.write(to: rootURL.appendingPathComponent("library.json"), options: .atomic)
    }

    private func validate(_ artifact: GeneratedArtifact) throws {
        guard artifact.pngData.starts(with: [0x89, 0x50, 0x4E, 0x47]) else {
            throw LocalLibraryError.invalidPNG
        }
        guard let data = artifact.recipeJSON.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil
        else {
            throw LocalLibraryError.invalidRecipe
        }
    }

    private func recordURL(id: UUID) -> URL {
        rootURL.appendingPathComponent("records/\(id.uuidString)", isDirectory: true)
    }

    private func revisionURL(recordID: UUID, revision: UUID) -> URL {
        recordURL(id: recordID).appendingPathComponent(revision.uuidString, isDirectory: true)
    }

    private func url(for relativePath: String) -> URL {
        rootURL.appendingPathComponent(relativePath)
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

private struct ArtifactPaths {
    let png: String
    let recipe: String
}

struct SavedConversionPreset: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let settings: PixelConversionSettings
    let algorithmVersion: String
    let createdAt: Date
    let updatedAt: Date
}

struct ConversionPresetSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion = currentSchemaVersion
    var presets: [SavedConversionPreset] = []
}

enum ConversionPresetStoreError: Error, Equatable {
    case emptyName
    case presetNotFound
    case unsupportedSchema(Int)
}

actor ConversionPresetStore {
    private let rootURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        rootURL: URL = LocalLibraryStore.defaultRootURL(),
        fileManager: FileManager = .default
    ) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadPresets() throws -> [SavedConversionPreset] {
        try loadSnapshot().presets.sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func savePreset(
        name: String,
        settings: PixelConversionSettings,
        algorithmVersion: String = PixelCoreInfo.algorithmVersion,
        now: Date = Date()
    ) throws -> SavedConversionPreset {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ConversionPresetStoreError.emptyName
        }

        var snapshot = try loadSnapshot()
        let normalizedName = Self.normalized(trimmedName)
        let preset: SavedConversionPreset
        if let index = snapshot.presets.firstIndex(where: {
            Self.normalized($0.name) == normalizedName
        }) {
            let previous = snapshot.presets[index]
            preset = SavedConversionPreset(
                id: previous.id,
                name: trimmedName,
                settings: settings,
                algorithmVersion: algorithmVersion,
                createdAt: previous.createdAt,
                updatedAt: now
            )
            snapshot.presets[index] = preset
        } else {
            preset = SavedConversionPreset(
                id: UUID(),
                name: trimmedName,
                settings: settings,
                algorithmVersion: algorithmVersion,
                createdAt: now,
                updatedAt: now
            )
            snapshot.presets.append(preset)
        }
        try save(snapshot)
        return preset
    }

    func deletePreset(id: UUID) throws {
        var snapshot = try loadSnapshot()
        guard snapshot.presets.contains(where: { $0.id == id }) else {
            throw ConversionPresetStoreError.presetNotFound
        }
        snapshot.presets.removeAll { $0.id == id }
        try save(snapshot)
    }

    private func loadSnapshot() throws -> ConversionPresetSnapshot {
        let manifestURL = rootURL.appendingPathComponent("conversion-presets.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return ConversionPresetSnapshot()
        }
        let snapshot = try decoder.decode(
            ConversionPresetSnapshot.self,
            from: Data(contentsOf: manifestURL)
        )
        guard snapshot.schemaVersion == ConversionPresetSnapshot.currentSchemaVersion else {
            throw ConversionPresetStoreError.unsupportedSchema(snapshot.schemaVersion)
        }
        return snapshot
    }

    private func save(_ snapshot: ConversionPresetSnapshot) throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(
            to: rootURL.appendingPathComponent("conversion-presets.json"),
            options: .atomic
        )
    }

    private static func normalized(_ name: String) -> String {
        name.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}
