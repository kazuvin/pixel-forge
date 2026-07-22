import SwiftUI
import UniformTypeIdentifiers

struct WorkbenchView: View {
    @EnvironmentObject private var entitlement: ProEntitlementService
    @StateObject private var model: HomeModel
    @State private var didLoadInitialURL = false
    @State private var pendingDeletion: GeneratedImageRecord?
    let initialURL: URL?
    let reviewCaptureURL: URL?

    init(initialURL: URL? = nil, reviewCaptureURL: URL? = nil) {
        self.initialURL = initialURL
        self.reviewCaptureURL = reviewCaptureURL
        let store: LocalLibraryStore
        if let reviewCaptureURL {
            store = LocalLibraryStore(
                rootURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent("PixelForgeReview", isDirectory: true)
                    .appendingPathComponent(reviewCaptureURL.lastPathComponent, isDirectory: true)
                    .appendingPathComponent(String(ProcessInfo.processInfo.processIdentifier), isDirectory: true)
            )
        } else {
            store = LocalLibraryStore()
        }
        _model = StateObject(wrappedValue: HomeModel(store: store))
    }

    var body: some View {
        ForgeCanvas {
            VStack(spacing: 0) {
                ForgeTopBar(
                    eyebrow: L10n.homeEyebrow,
                    title: L10n.workbenchTitle,
                    subtitle: L10n.homeSubtitle
                ) {
                    HStack(spacing: ForgeDesign.Spacing.compact) {
                        ForgeSettingsButton(label: L10n.settings)
                        ForgeButton(
                            title: L10n.choosePhoto,
                            icon: .addPhoto,
                            role: .primary,
                            fillsWidth: false
                        ) {
                            model.isShowingImporter = true
                        }
                        .keyboardShortcut("o", modifiers: .command)
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
        .fileImporter(
            isPresented: $model.isShowingImporter,
            allowedContentTypes: [.png, .jpeg, .portablePixmap],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.load(url: url, entitlement: entitlement)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            model.load(url: url, entitlement: entitlement)
            return true
        }
        .sheet(item: $model.session) { session in
            ConversionModalView(
                model: session,
                reviewCaptureURL: reviewCaptureURL,
                close: { model.session = nil }
            )
            .interactiveDismissDisabled(session.state == .rendering)
        }
        .confirmationDialog(
            L10n.deleteConfirmation,
            isPresented: deletionIsPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.delete, role: .destructive) {
                guard let pendingDeletion else { return }
                Task { await model.delete(pendingDeletion) }
                self.pendingDeletion = nil
            }
            Button(L10n.cancel, role: .cancel) {
                pendingDeletion = nil
            }
        }
        .task {
            await entitlement.start()
            await model.loadLibrary()
        }
        .task(id: initialURL) {
            guard !didLoadInitialURL, let initialURL else { return }
            didLoadInitialURL = true
            model.load(
                url: initialURL,
                entitlement: entitlement,
                autoConvert: reviewCaptureURL != nil
            )
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
                ) {
                    model.isShowingImporter = true
                }
            }
            .padding(ForgeDesign.Spacing.roomy)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            GeometryReader { proxy in
                ScrollView {
                    if let errorMessage = model.errorMessage {
                        ForgeAlertBanner(message: errorMessage)
                            .padding(.bottom, ForgeDesign.Spacing.regular)
                    }
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.flexible(), spacing: ForgeDesign.Spacing.regular),
                            count: proxy.size.width < 720 ? 1 : 2
                        ),
                        spacing: ForgeDesign.Spacing.regular
                    ) {
                        ForEach(model.records) { record in
                            ForgeGeneratedCard(
                                image: model.thumbnails[record.id],
                                title: record.sourceFilename,
                                detail: "\(record.metadata.logicalWidth) × \(record.metadata.logicalHeight) → \(record.metadata.outputWidth) × \(record.metadata.outputHeight)",
                                updated: Self.dateFormatter.string(from: record.updatedAt),
                                open: {
                                    Task { await model.open(record, entitlement: entitlement) }
                                },
                                delete: {
                                    pendingDeletion = record
                                }
                            )
                        }
                    }
                }
                .padding(ForgeDesign.Spacing.roomy)
            }
        }
    }

    private var deletionIsPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension UTType {
    static let portablePixmap = UTType(filenameExtension: "ppm") ?? .data
}
