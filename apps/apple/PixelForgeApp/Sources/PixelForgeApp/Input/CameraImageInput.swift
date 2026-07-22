import AVFoundation
import SwiftUI
import UIKit

enum ImageSourceOption: Hashable, Identifiable {
    case camera
    case photoLibrary
    case files

    var id: Self { self }

    static func available(cameraAvailable: Bool) -> [Self] {
        cameraAvailable ? [.camera, .photoLibrary, .files] : [.photoLibrary, .files]
    }

    var title: String {
        switch self {
        case .camera:
            L10n.takePhoto
        case .photoLibrary:
            L10n.choosePhoto
        case .files:
            L10n.chooseFile
        }
    }
}

enum CameraAccessDecision: Equatable {
    case presentPicker
    case requestPermission
    case showSettings
}

enum CameraAccessPolicy {
    static func decision(for status: AVAuthorizationStatus) -> CameraAccessDecision {
        switch status {
        case .authorized:
            .presentPicker
        case .notDetermined:
            .requestPermission
        case .denied, .restricted:
            .showSettings
        @unknown default:
            .showSettings
        }
    }
}

struct CameraCapture {
    let data: Data
    let filename: String
}

enum CameraCaptureEncoder {
    @MainActor
    static func jpegData(from image: UIImage) -> Data? {
        guard image.imageOrientation != .up else {
            return image.jpegData(compressionQuality: 0.95)
        }
        guard let cgImage = image.cgImage else { return nil }

        let swapsDimensions: Bool
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            swapsDimensions = true
        case .up, .upMirrored, .down, .downMirrored:
            swapsDimensions = false
        @unknown default:
            swapsDimensions = false
        }

        let size = swapsDimensions
            ? CGSize(width: cgImage.height, height: cgImage.width)
            : CGSize(width: cgImage.width, height: cgImage.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let normalized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return normalized.jpegData(compressionQuality: 0.95)
    }
}

struct CameraImagePicker: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraImagePicker

        init(parent: CameraImagePicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            parent.onCancel()
        }

        func imagePickerController(
            _: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.onFailure()
                return
            }
            parent.onCapture(image)
        }
    }
}
