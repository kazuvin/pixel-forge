import AVFoundation
import Testing
import UIKit
@testable import PixelForgeApp

@Suite("App language")
struct AppLanguageTests {
    @Test("system language resolves every supported locale and otherwise falls back to English")
    func resolvesSystemLanguage() {
        #expect(AppLanguage.system.resolvedLanguageCode(preferredLanguages: ["ja-JP"]) == "ja")
        #expect(AppLanguage.system.resolvedLanguageCode(preferredLanguages: ["en-US"]) == "en")
        #expect(AppLanguage.system.resolvedLanguageCode(preferredLanguages: ["ko-KR"]) == "ko")
        #expect(AppLanguage.system.resolvedLanguageCode(preferredLanguages: ["zh-Hant-TW"]) == "zh-Hant")
        #expect(AppLanguage.system.resolvedLanguageCode(preferredLanguages: ["zh-TW"]) == "zh-Hant")
        #expect(AppLanguage.system.resolvedLanguageCode(preferredLanguages: ["fr-FR", "ja-JP"]) == "en")
        #expect(AppLanguage.system.resolvedLanguageCode(preferredLanguages: []) == "en")
    }

    @Test("manual language ignores the system preference")
    func resolvesManualLanguage() {
        #expect(AppLanguage.english.resolvedLanguageCode(preferredLanguages: ["ja-JP"]) == "en")
        #expect(AppLanguage.japanese.resolvedLanguageCode(preferredLanguages: ["en-US"]) == "ja")
        #expect(AppLanguage.korean.resolvedLanguageCode(preferredLanguages: ["en-US"]) == "ko")
        #expect(AppLanguage.traditionalChinese.resolvedLanguageCode(preferredLanguages: ["en-US"]) == "zh-Hant")
    }
}

@Suite("Image source menu")
struct ImageSourceOptionTests {
    @Test("camera is the first option when the device supports capture")
    func includesAvailableCamera() {
        #expect(ImageSourceOption.available(cameraAvailable: true) == [.camera, .photoLibrary, .files])
    }

    @Test("camera is omitted when capture is unavailable")
    func omitsUnavailableCamera() {
        #expect(ImageSourceOption.available(cameraAvailable: false) == [.photoLibrary, .files])
    }

    @Test("camera authorization states choose the correct next step")
    func resolvesCameraAuthorization() {
        #expect(CameraAccessPolicy.decision(for: .authorized) == .presentPicker)
        #expect(CameraAccessPolicy.decision(for: .notDetermined) == .requestPermission)
        #expect(CameraAccessPolicy.decision(for: .denied) == .showSettings)
        #expect(CameraAccessPolicy.decision(for: .restricted) == .showSettings)
    }

    @Test("camera JPEG applies the captured image orientation")
    @MainActor
    func normalizesCameraOrientation() throws {
        let original = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 1)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
        }
        let cgImage = try #require(original.cgImage)
        let rotated = UIImage(cgImage: cgImage, scale: 1, orientation: .right)

        let data = try #require(CameraCaptureEncoder.jpegData(from: rotated))
        let decoded = try #require(UIImage(data: data))

        #expect(decoded.imageOrientation == .up)
        #expect(decoded.cgImage?.width == cgImage.height)
        #expect(decoded.cgImage?.height == cgImage.width)
    }
}

@MainActor
@Suite("Forge toast notifications")
struct ForgeToastCenterTests {
    @Test("notifications stack in arrival order")
    func stacksNotifications() {
        let center = ForgeToastCenter(
            displayNanoseconds: 60_000_000_000,
            maxVisibleCount: 4
        )

        center.show("Saved", style: .success)
        center.show("Check settings", style: .warning)
        center.show("Failed", style: .error)

        #expect(center.toasts.map(\.message) == ["Saved", "Check settings", "Failed"])
        #expect(center.toasts.map(\.style) == [.success, .warning, .error])
    }

    @Test("the oldest notification leaves when the visible stack is full")
    func trimsOverflowingStack() {
        let center = ForgeToastCenter(
            displayNanoseconds: 60_000_000_000,
            maxVisibleCount: 2
        )

        center.show("First", style: .success)
        center.show("Second", style: .warning)
        center.show("Third", style: .error)

        #expect(center.toasts.map(\.message) == ["Second", "Third"])
    }

    @Test("notifications disappear after the shared display interval")
    func dismissesAfterDisplayInterval() async throws {
        let center = ForgeToastCenter(
            displayNanoseconds: 20_000_000,
            maxVisibleCount: 4
        )

        center.show("Temporary", style: .success)
        #expect(center.toasts.count == 1)

        try await Task.sleep(for: .milliseconds(80))

        #expect(center.toasts.isEmpty)
    }
}
