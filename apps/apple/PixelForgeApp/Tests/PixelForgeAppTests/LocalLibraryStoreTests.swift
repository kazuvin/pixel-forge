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
