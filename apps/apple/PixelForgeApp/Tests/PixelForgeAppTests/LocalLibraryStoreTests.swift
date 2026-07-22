import Foundation
import PixelCoreKit
import Testing
@testable import PixelForgeApp

@Suite("Local image library")
struct LocalLibraryStoreTests {
    @Test("identical source bytes are shared across generated records")
    func deduplicatesSources() async throws {
        let root = try temporaryDirectory()
        let store = LocalLibraryStore(rootURL: root)
        let source = Data("same source".utf8)

        _ = try await store.createRecord(
            sourceData: source,
            sourceFilename: "photo.jpg",
            artifact: artifact(seed: 1),
            now: Date(timeIntervalSince1970: 10)
        )
        _ = try await store.createRecord(
            sourceData: source,
            sourceFilename: "photo-copy.jpg",
            artifact: artifact(seed: 2),
            now: Date(timeIntervalSince1970: 20)
        )

        let snapshot = try await store.loadSnapshot()
        #expect(snapshot.sources.count == 1)
        #expect(snapshot.records.count == 2)
        #expect(snapshot.records[0].sourceHash == snapshot.records[1].sourceHash)
    }

    @Test("failed overwrite preserves the previous record and files")
    func failedOverwriteIsAtomic() async throws {
        let root = try temporaryDirectory()
        let store = LocalLibraryStore(rootURL: root)
        let original = try await store.createRecord(
            sourceData: Data("source".utf8),
            sourceFilename: "photo.ppm",
            artifact: artifact(seed: 1),
            now: Date(timeIntervalSince1970: 10)
        )
        let originalPNG = try await store.pngData(for: original)

        let invalid = GeneratedArtifact(
            pngData: Data("not a png".utf8),
            recipeJSON: "{}",
            metadata: artifact(seed: 2).metadata
        )
        await #expect(throws: LocalLibraryError.invalidPNG) {
            _ = try await store.updateRecord(
                id: original.id,
                artifact: invalid,
                now: Date(timeIntervalSince1970: 20)
            )
        }

        let snapshot = try await store.loadSnapshot()
        #expect(snapshot.records == [original])
        #expect(try await store.pngData(for: original) == originalPNG)
    }

    @Test("source bytes are removed only after their last record is deleted")
    func deletesUnreferencedSources() async throws {
        let root = try temporaryDirectory()
        let store = LocalLibraryStore(rootURL: root)
        let source = Data("same source".utf8)
        let first = try await store.createRecord(
            sourceData: source,
            sourceFilename: "photo.jpg",
            artifact: artifact(seed: 1)
        )
        let second = try await store.createRecord(
            sourceData: source,
            sourceFilename: "photo.jpg",
            artifact: artifact(seed: 2)
        )

        try await store.deleteRecord(id: first.id)
        #expect(try await store.loadSnapshot().sources.count == 1)

        try await store.deleteRecord(id: second.id)
        let empty = try await store.loadSnapshot()
        #expect(empty.records.isEmpty)
        #expect(empty.sources.isEmpty)
    }

    @Test("conversion presets preserve settings and replace the same normalized name")
    func persistsAndUpdatesConversionPresets() async throws {
        let root = try temporaryDirectory()
        let store = ConversionPresetStore(rootURL: root)
        let originalSettings = PixelConversionSettings(
            longSide: 96,
            upscale: 4,
            colorMode: .palette(
                PixelPalette(
                    name: "Mono",
                    colors: [.init(red: 1, green: 2, blue: 3)]
                ),
                application: .preserveTone(saturation: 45, lightness: 65)
            ),
            outline: .init(mode: .adaptive, threshold: 25)
        )
        let created = try await store.savePreset(
            name: " Portrait ",
            settings: originalSettings,
            algorithmVersion: "1.2.0",
            now: Date(timeIntervalSince1970: 10)
        )

        let loaded = try await store.loadPresets()
        #expect(loaded == [created])
        #expect(loaded.first?.name == "Portrait")
        #expect(loaded.first?.settings == originalSettings)

        let updatedSettings = PixelConversionSettings(longSide: 32, upscale: 8)
        let updated = try await store.savePreset(
            name: "portrait",
            settings: updatedSettings,
            algorithmVersion: "1.3.0",
            now: Date(timeIntervalSince1970: 20)
        )
        let afterUpdate = try await store.loadPresets()
        #expect(afterUpdate.count == 1)
        #expect(updated.id == created.id)
        #expect(updated.createdAt == created.createdAt)
        #expect(updated.settings == updatedSettings)

        try await store.deletePreset(id: created.id)
        #expect(try await store.loadPresets().isEmpty)
    }

    @Test("conversion presets require a visible name")
    func rejectsEmptyPresetName() async throws {
        let store = ConversionPresetStore(rootURL: try temporaryDirectory())
        await #expect(throws: ConversionPresetStoreError.emptyName) {
            try await store.savePreset(name: "  \n ", settings: PixelConversionSettings())
        }
    }

    private func artifact(seed: UInt8) -> GeneratedArtifact {
        GeneratedArtifact(
            pngData: Data([0x89, 0x50, 0x4E, 0x47, seed]),
            recipeJSON: "{\"schemaVersion\":2,\"seed\":\(seed)}",
            metadata: GeneratedImageMetadata(
                logicalWidth: 64,
                logicalHeight: 48,
                outputWidth: 512,
                outputHeight: 384,
                paletteName: nil,
                algorithmVersion: "1.2.0"
            )
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PixelForgeTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
