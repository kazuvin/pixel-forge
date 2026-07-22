import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct WorkbenchView: View {
    @EnvironmentObject private var entitlement: ProEntitlementService
    @StateObject private var model = HomeModel()
    let reviewScreen: ReviewScreen?
    @State private var pendingDeletion: GeneratedImageRecord?
    @State private var selectedRecordForActions: GeneratedImageRecord?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var pendingCameraCapture: CameraCapture?
    @State private var showsCameraPicker = false
    @State private var showsCameraPermissionAlert = false
    @State private var showsPhotoPicker = false
    @State private var showsFileImporter = false
    @State private var showsSourceMenu = false
    @State private var showsSettings = false

    init(reviewScreen: ReviewScreen? = nil) {
        self.reviewScreen = reviewScreen
    }

    var body: some View {
        ForgeCanvas {
            VStack(spacing: 0) {
                ForgeTopBar(
                    eyebrow: L10n.homeEyebrow,
                    title: L10n.workbenchTitle,
                    subtitle: L10n.homeSubtitle
                ) {
                    HStack(spacing: ForgeDesign.Spacing.tight) {
                        ForgeSettingsButton(label: L10n.settings) {
                            showsSettings = true
                        }
                        ForgeIconButton(icon: .addPhoto, accessibilityLabel: L10n.choosePhoto) {
                            showsSourceMenu = true
                        }
                    }
                }
                ForgeDivider()
                homeContent
                ForgeDivider()
                ForgeStatusStrip(
                    status: L10n.localLibrary,
                    detail: L10n.imageCount(model.records.count),
                    trailing: L10n.deterministic,
                    isActive: !model.records.isEmpty
                )
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showsSettings) {
            ThemeSettingsView(opensLanguageSelector: reviewScreen == .settingsLanguageSelector)
                .environmentObject(entitlement)
        }
        .photosPicker(
            isPresented: $showsPhotoPicker,
            selection: $selectedPhoto,
            matching: .images,
            preferredItemEncoding: .compatible
        )
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.png, .jpeg, .portablePixmap],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.load(url: url, entitlement: entitlement)
            }
        }
        .fullScreenCover(isPresented: $showsCameraPicker, onDismiss: finishCameraCapture) {
            CameraImagePicker(
                onCapture: receiveCameraImage,
                onCancel: { showsCameraPicker = false },
                onFailure: {
                    model.errorMessage = L10n.cameraCaptureFailed
                    showsCameraPicker = false
                }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $model.session) { session in
            ConversionModalView(
                model: session,
                opensPalettePicker: reviewScreen == .palettePicker,
                opensPresetLibrary: reviewScreen == .recipePresetLibrary,
                opensStylePicker: reviewScreen == .conversionStylePicker,
                opensAdvancedSettings: reviewScreen == .conversionAdvanced
            ) {
                model.session = nil
            }
            .environmentObject(entitlement)
        }
        .forgeOverlay {
            ForgeActionMenu(
                isPresented: $showsSourceMenu,
                eyebrow: L10n.imageSourceEyebrow,
                title: L10n.chooseImage,
                items: imageSourceOptions.map { source in
                    ForgeActionMenuItem(
                        id: String(describing: source),
                        title: source.title,
                        icon: source.icon,
                        action: { select(source) }
                    )
                },
                cancelTitle: L10n.cancel
            )
        }
        .forgeOverlay {
            ForgeContextActionDialog(
                isPresented: recordActionIsPresented,
                eyebrow: L10n.recordActionsEyebrow,
                title: selectedRecordForActions?.sourceFilename ?? L10n.recordActionsTitle,
                detail: L10n.recordActionsDetail,
                items: recordActionItems,
                cancelTitle: L10n.cancel
            )
        }
        .forgeOverlay {
            ForgeConfirmationDialog(
                isPresented: deletionIsPresented,
                eyebrow: L10n.deleteEyebrow,
                title: L10n.deleteTitle,
                detail: L10n.deleteDetail,
                confirmTitle: L10n.delete,
                cancelTitle: L10n.cancel
            ) {
                guard let pendingDeletion else { return }
                Task { await model.delete(pendingDeletion) }
                self.pendingDeletion = nil
            }
        }
        .alert(L10n.cameraPermissionTitle, isPresented: $showsCameraPermissionAlert) {
            Button(L10n.openSettings) {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.cameraPermissionDetail)
        }
        .task {
            await prepareInitialState()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else { return }
                    model.load(data: data, filename: "Photo.jpg", entitlement: entitlement)
                } catch {
                    model.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func prepareInitialState() async {
        await entitlement.start()
        guard let reviewScreen, let sourceData = ReviewConfiguration.sourceData else {
            await model.loadLibrary()
            return
        }
        switch reviewScreen {
        case .home:
            model.prepareReviewHome(imageData: sourceData)
        case .imageSourceMenu:
            model.prepareReviewHome(imageData: sourceData)
            showsSourceMenu = true
        case .deleteDialog:
            model.prepareReviewHome(imageData: sourceData)
            pendingDeletion = model.records.first
        case .recordActionDialog:
            model.prepareReviewHome(imageData: sourceData)
            selectedRecordForActions = model.records.first
        case .conversionEditing:
            model.load(data: sourceData, filename: "review-gradient.png", entitlement: entitlement)
        case .conversionAdvanced:
            model.load(data: sourceData, filename: "review-gradient.png", entitlement: entitlement)
        case .conversionStylePicker:
            model.load(data: sourceData, filename: "review-gradient.png", entitlement: entitlement)
            model.session?.prepareReviewPresets()
        case .palettePicker:
            model.load(data: sourceData, filename: "review-gradient.png", entitlement: entitlement)
            model.session?.paletteSelection = .custom
        case .recipePresetLibrary:
            model.load(data: sourceData, filename: "review-gradient.png", entitlement: entitlement)
            model.session?.prepareReviewPresets()
        case .conversionResult:
            model.load(data: sourceData, filename: "review-gradient.png", entitlement: entitlement)
            model.session?.convert(saveMode: .newRecord)
        case .settings, .settingsDeveloper, .settingsLanguageSelector:
            showsSettings = true
        }
    }

    private var imageSourceOptions: [ImageSourceOption] {
        ImageSourceOption.available(
            cameraAvailable: reviewScreen == .imageSourceMenu || UIImagePickerController.isSourceTypeAvailable(.camera)
        )
    }

    private func select(_ source: ImageSourceOption) {
        switch source {
        case .camera:
            openCamera()
        case .photoLibrary:
            showsPhotoPicker = true
        case .files:
            showsFileImporter = true
        }
    }

    private func openCamera() {
        switch CameraAccessPolicy.decision(for: AVCaptureDevice.authorizationStatus(for: .video)) {
        case .presentPicker:
            showsCameraPicker = true
        case .requestPermission:
            Task {
                if await AVCaptureDevice.requestAccess(for: .video) {
                    showsCameraPicker = true
                } else {
                    showsCameraPermissionAlert = true
                }
            }
        case .showSettings:
            showsCameraPermissionAlert = true
        }
    }

    private func receiveCameraImage(_ image: UIImage) {
        guard let data = CameraCaptureEncoder.jpegData(from: image) else {
            model.errorMessage = L10n.cameraCaptureFailed
            showsCameraPicker = false
            return
        }
        pendingCameraCapture = CameraCapture(data: data, filename: Self.cameraFilenameFormatter.string(from: Date()))
        showsCameraPicker = false
    }

    private func finishCameraCapture() {
        guard let capture = pendingCameraCapture else { return }
        pendingCameraCapture = nil
        model.load(data: capture.data, filename: capture.filename, entitlement: entitlement)
    }

    @ViewBuilder
    private var homeContent: some View {
        if model.records.isEmpty {
            VStack(spacing: ForgeDesign.Spacing.regular) {
                if let errorMessage = model.errorMessage {
                    ForgeAlertBanner(message: errorMessage)
                }
                if let actionMessage = model.actionMessage {
                    ForgeSuccessBanner(message: actionMessage)
                }
                ForgeLibraryEmpty(
                    title: L10n.homeEmptyTitle,
                    detail: L10n.homeEmptyDetail,
                    actionTitle: L10n.chooseImage
                ) { showsSourceMenu = true }
            }
            .padding(.horizontal, ForgeDesign.Spacing.regular)
            .padding(.top, ForgeDesign.Spacing.regular)
            .padding(.bottom, ForgeDesign.Spacing.regular)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: ForgeDesign.Spacing.compact) {
                    if let errorMessage = model.errorMessage {
                        ForgeAlertBanner(message: errorMessage)
                    }
                    if let actionMessage = model.actionMessage {
                        ForgeSuccessBanner(message: actionMessage)
                    }
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: ForgeDesign.Spacing.compact
                    ) {
                        ForEach(model.records) { record in
                            ForgeGeneratedCard(
                                image: model.thumbnails[record.id],
                                title: record.sourceFilename,
                                detail: "\(record.metadata.logicalWidth)×\(record.metadata.logicalHeight) → \(record.metadata.outputWidth)×\(record.metadata.outputHeight)",
                                updated: AppLanguage.selected.formattedLibraryDate(record.updatedAt),
                                open: { Task { await model.open(record, entitlement: entitlement) } },
                                showActions: { selectedRecordForActions = record }
                            )
                        }
                    }
                }
                .padding(.horizontal, ForgeDesign.Spacing.compact)
                .padding(.top, ForgeDesign.Spacing.regular)
                .padding(.bottom, ForgeDesign.Spacing.compact)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
    }

    private var deletionIsPresented: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    private var recordActionIsPresented: Binding<Bool> {
        Binding(
            get: { selectedRecordForActions != nil },
            set: { if !$0 { selectedRecordForActions = nil } }
        )
    }

    private var recordActionItems: [ForgeDialogActionItem] {
        guard let record = selectedRecordForActions else { return [] }
        return [
            ForgeDialogActionItem(id: "adjust", title: L10n.adjust, icon: .edit) {
                Task { await model.adjust(record, entitlement: entitlement) }
            },
            ForgeDialogActionItem(id: "save", title: L10n.saveToPhotos, icon: .savePhoto) {
                Task { await model.saveToPhotos(record) }
            },
            ForgeDialogActionItem(id: "duplicate", title: L10n.duplicate, icon: .duplicate) {
                Task { await model.duplicate(record) }
            },
            ForgeDialogActionItem(
                id: "delete",
                title: L10n.delete,
                icon: .trash,
                role: .destructive
            ) {
                pendingDeletion = record
            },
        ]
    }

    private static let cameraFilenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "'Camera-'yyyyMMdd-HHmmss'.jpg'"
        return formatter
    }()
}

private extension UTType {
    static let portablePixmap = UTType(filenameExtension: "ppm") ?? .data
}
