import PixelCoreKit
import SwiftUI
import UniformTypeIdentifiers

struct WorkbenchView: View {
    @StateObject private var model = WorkbenchModel()
    @State private var didLoadInitialURL = false
    let initialURL: URL?
    let reviewCaptureURL: URL?

    init(initialURL: URL? = nil, reviewCaptureURL: URL? = nil) {
        self.initialURL = initialURL
        self.reviewCaptureURL = reviewCaptureURL
    }

    var body: some View {
        ForgeCanvas {
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    topBar
                    ForgeDivider()
                    previews
                    ForgeDivider()
                    ForgeStatusStrip(
                        status: statusText,
                        detail: model.sourceName,
                        trailing: L10n.deterministic,
                        isActive: model.sourceImage != nil
                    )
                }
                recipePanel
            }
        }
        .fileImporter(
            isPresented: $model.isShowingImporter,
            allowedContentTypes: [.png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.load(url: url)
            }
        }
        .task(id: initialURL) {
            guard !didLoadInitialURL, let initialURL else { return }
            didLoadInitialURL = true
            model.load(url: initialURL)
        }
        .onChange(of: model.outputImage != nil) { _, hasOutput in
            guard hasOutput, let reviewCaptureURL else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(800))
                ReviewCapture.saveMainWindow(to: reviewCaptureURL)
            }
        }
    }

    private var topBar: some View {
        ForgeTopBar(
            eyebrow: L10n.workbenchEyebrow,
            title: L10n.workbenchTitle,
            subtitle: model.sourceName
        ) {
            HStack(spacing: ForgeDesign.Spacing.compact) {
                ForgeSettingsButton(label: L10n.settings)
                ForgeButton(
                    title: L10n.choosePhoto,
                    icon: .addPhoto,
                    fillsWidth: false
                ) {
                    model.isShowingImporter = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }

    private var previews: some View {
        HStack(spacing: ForgeDesign.Spacing.regular) {
            ForgePreviewPane(
                label: L10n.input,
                metadata: model.sourceDimensions,
                image: model.sourceImage,
                pixelated: false,
                emptyMessage: L10n.inputEmpty
            )
            ForgePreviewPane(
                label: L10n.output,
                metadata: model.outputDimensions,
                image: model.outputImage,
                pixelated: true,
                emptyMessage: L10n.outputEmpty
            )
        }
        .padding(ForgeDesign.Spacing.regular)
    }

    private var recipePanel: some View {
        ForgeSidebar {
            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.roomy) {
                ForgeSectionHeader(
                    eyebrow: "\(L10n.recipeEyebrow) / \(PixelCoreInfo.algorithmVersion)",
                    title: L10n.recipeTitle,
                    detail: L10n.recipeSubtitle
                )

                ForgePixelSurface(level: .surface, padding: ForgeDesign.Spacing.compact) {
                    VStack(spacing: ForgeDesign.Spacing.compact) {
                        ForgeMetricStepper(
                            title: L10n.width,
                            value: $model.targetWidth,
                            range: 8 ... 512,
                            step: 8,
                            valueLabel: L10n.pixels(model.targetWidth)
                        )
                        ForgeMetricStepper(
                            title: L10n.height,
                            value: $model.targetHeight,
                            range: 8 ... 512,
                            step: 8,
                            valueLabel: L10n.pixels(model.targetHeight)
                        )
                        ForgeMetricStepper(
                            title: L10n.colors,
                            value: $model.colorCount,
                            range: 2 ... 64,
                            step: 1,
                            valueLabel: L10n.colorCount(model.colorCount)
                        )
                        ForgeMetricStepper(
                            title: L10n.upscale,
                            value: $model.upscale,
                            range: 1 ... 32,
                            step: 1,
                            valueLabel: L10n.scale(model.upscale)
                        )
                    }
                }

                ForgeLabeledControl(label: L10n.dither) {
                    ForgeSegmentedControl(
                        selection: $model.dither,
                        options: PixelDitherMode.allCases.map { mode in
                            ForgeSegmentOption(
                                id: mode.rawValue,
                                value: mode,
                                title: L10n.ditherName(mode)
                            )
                        }
                    )
                }

                if let errorMessage = model.errorMessage {
                    ForgeAlertBanner(message: errorMessage)
                }

                Spacer(minLength: ForgeDesign.Spacing.compact)

                VStack(spacing: ForgeDesign.Spacing.compact) {
                    ForgeButton(
                        title: model.isRendering ? L10n.rendering : L10n.render,
                        icon: .render,
                        role: .primary
                    ) {
                        model.render()
                    }
                    .disabled(model.sourceImage == nil || model.isRendering)

                    ForgeButton(
                        title: L10n.export,
                        icon: .export
                    ) {
                        model.export()
                    }
                    .disabled(model.outputImage == nil || model.isRendering)
                }
            }
        }
    }

    private var statusText: String {
        if model.isRendering {
            L10n.statusRendering
        } else if model.outputImage != nil {
            L10n.statusRendered
        } else if model.sourceImage != nil {
            L10n.statusReady
        } else {
            L10n.statusWaiting
        }
    }
}
