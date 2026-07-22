import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct WorkbenchView: View {
    @EnvironmentObject private var entitlement: ProEntitlementService
    @StateObject private var model = HomeModel()
    let reviewScreen: ReviewScreen?
    @State private var pendingDeletion: GeneratedImageRecord?
    @State private var selectedPhoto: PhotosPickerItem?
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
        .navigationDestination(isPresented: $showsSettings) {
            ThemeSettingsView()
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
        .confirmationDialog(L10n.chooseImage, isPresented: $showsSourceMenu) {
            Button(L10n.choosePhoto) { showsPhotoPicker = true }
            Button(L10n.chooseFile) { showsFileImporter = true }
            Button(L10n.cancel, role: .cancel) {}
        }
        .fullScreenCover(item: $model.session) { session in
            ConversionModalView(model: session) {
                model.session = nil
            }
            .environmentObject(entitlement)
        }
        .confirmationDialog(L10n.deleteConfirmation, isPresented: deletionIsPresented) {
            Button(L10n.delete, role: .destructive) {
                guard let pendingDeletion else { return }
                Task { await model.delete(pendingDeletion) }
                self.pendingDeletion = nil
            }
            Button(L10n.cancel, role: .cancel) { pendingDeletion = nil }
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
        case .conversionEditing:
            model.load(data: sourceData, filename: "review-gradient.png", entitlement: entitlement)
        case .conversionResult:
            model.load(data: sourceData, filename: "review-gradient.png", entitlement: entitlement)
            model.session?.convert(saveMode: .newRecord)
        case .settings:
            showsSettings = true
        }
    }

    @ViewBuilder
    private var homeContent: some View {
        if model.records.isEmpty {
            VStack(spacing: ForgeDesign.Spacing.regular) {
                if let errorMessage = model.errorMessage {
                    ForgeAlertBanner(message: errorMessage)
                }
                ForgeLibraryEmpty(
                    title: L10n.homeEmptyTitle,
                    detail: L10n.homeEmptyDetail,
                    actionTitle: L10n.chooseImage
                ) { showsSourceMenu = true }
            }
            .padding(ForgeDesign.Spacing.regular)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                if let errorMessage = model.errorMessage {
                    ForgeAlertBanner(message: errorMessage)
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
                            updated: Self.dateFormatter.string(from: record.updatedAt),
                            open: { Task { await model.open(record, entitlement: entitlement) } },
                            delete: { pendingDeletion = record }
                        )
                    }
                }
            }
            .padding(ForgeDesign.Spacing.compact)
        }
    }

    private var deletionIsPresented: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension UTType {
    static let portablePixmap = UTType(filenameExtension: "ppm") ?? .data
}
