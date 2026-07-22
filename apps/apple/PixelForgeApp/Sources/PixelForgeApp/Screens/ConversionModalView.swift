import PixelCoreKit
import SwiftUI

struct ConversionModalView: View {
    @ObservedObject var model: ConversionSessionModel
    let reviewCaptureURL: URL?
    let close: () -> Void

    var body: some View {
        ForgeCanvas {
            VStack(spacing: 0) {
                ForgeModalHeader(
                    eyebrow: modalEyebrow,
                    title: model.sourceFilename,
                    detail: model.sourceDimensionsLabel,
                    close: close
                )
                ForgeDivider()
                modalContent
            }
        }
        .frame(width: 980, height: 720)
        .task {
            captureReviewIfNeeded(for: model.state)
        }
        .onChange(of: model.state) { _, state in
            captureReviewIfNeeded(for: state)
        }
    }

    @ViewBuilder
    private var modalContent: some View {
        switch model.state {
        case .editing:
            editor
        case .rendering:
            ForgeConversionLoading(
                isVisible: model.showsLoader,
                title: L10n.rendering,
                detail: L10n.renderingDetail
            )
            .padding(ForgeDesign.Spacing.roomy)
        case .result:
            result
        case .failure:
            failure
        }
    }

    private var editor: some View {
        HStack(spacing: 0) {
            ForgePreviewPane(
                label: L10n.input,
                metadata: model.sourceDimensionsLabel,
                image: model.sourceImage,
                pixelated: false,
                emptyMessage: L10n.inputEmpty
            )
            .padding(ForgeDesign.Spacing.roomy)
            ForgeSidebar {
                ScrollView {
                    VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
                        ForgeSectionHeader(
                            eyebrow: L10n.recipeEyebrow,
                            title: L10n.conversionOptions,
                            detail: L10n.conversionOptionsDetail
                        )
                        ForgeMetricStepper(
                            title: L10n.longSide,
                            value: $model.longSide,
                            range: 1 ... 1024,
                            step: 1,
                            valueLabel: L10n.pixels(model.longSide),
                            isLocked: !model.isProActive
                        )
                        ForgeMetricStepper(
                            title: L10n.upscale,
                            value: $model.upscale,
                            range: 1 ... 32,
                            step: 1,
                            valueLabel: L10n.scale(model.upscale),
                            isLocked: !model.isProActive
                        )
                        cropControls
                        paletteControls
                        outlineControls
                        if model.requiresPro {
                            ForgeAlertBanner(message: L10n.proRequired)
                        }
                        if let errorMessage = model.errorMessage {
                            ForgeAlertBanner(message: errorMessage)
                        }
                        actionButtons
                    }
                }
            }
            .onChange(of: model.longSide) { _, _ in model.refreshProRequirement() }
            .onChange(of: model.upscale) { _, _ in model.refreshProRequirement() }
            .onChange(of: model.paletteSelection) { _, _ in model.refreshProRequirement() }
            .onChange(of: model.preservesTone) { _, _ in model.refreshProRequirement() }
            .onChange(of: model.outlineMode) { _, _ in model.refreshProRequirement() }
        }
    }

    private var cropControls: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
            ForgeLabeledControl(label: L10n.crop) {
                ForgeSegmentedControl(
                    selection: $model.cropSelection,
                    options: [
                        ForgeSegmentOption(id: "full", value: .full, title: L10n.cropFull),
                        ForgeSegmentOption(id: "rectangle", value: .rectangle, title: L10n.cropRectangle),
                    ]
                )
            }
            if model.cropSelection == .rectangle {
                ForgePixelSurface(level: .surface, padding: ForgeDesign.Spacing.tight) {
                    VStack(spacing: ForgeDesign.Spacing.tight) {
                        ForgeMetricStepper(
                            title: "X",
                            value: $model.cropX,
                            range: 0 ... max(0, Int(model.sourceDimensions.width) - 1),
                            step: 1,
                            valueLabel: L10n.pixels(model.cropX)
                        )
                        ForgeMetricStepper(
                            title: "Y",
                            value: $model.cropY,
                            range: 0 ... max(0, Int(model.sourceDimensions.height) - 1),
                            step: 1,
                            valueLabel: L10n.pixels(model.cropY)
                        )
                        ForgeMetricStepper(
                            title: L10n.width,
                            value: $model.cropWidth,
                            range: 1 ... max(1, Int(model.sourceDimensions.width)),
                            step: 1,
                            valueLabel: L10n.pixels(model.cropWidth)
                        )
                        ForgeMetricStepper(
                            title: L10n.height,
                            value: $model.cropHeight,
                            range: 1 ... max(1, Int(model.sourceDimensions.height)),
                            step: 1,
                            valueLabel: L10n.pixels(model.cropHeight)
                        )
                    }
                }
            }
        }
    }

    private var paletteControls: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
            ForgeLabeledControl(label: L10n.palette, isLocked: !model.isProActive) {
                ForgeSegmentedControl(
                    selection: $model.paletteSelection,
                    options: [
                        ForgeSegmentOption(id: "source", value: .source, title: L10n.paletteSource),
                        ForgeSegmentOption(id: "game-boy", value: .gameBoy, title: "GB"),
                        ForgeSegmentOption(id: "pico-8", value: .pico8, title: "PICO"),
                        ForgeSegmentOption(id: "custom", value: .custom, title: L10n.custom),
                    ]
                )
            }
            if model.paletteSelection == .custom {
                ForgeTextInput(label: L10n.customPalette, text: $model.customPaletteText)
            }
            if model.paletteSelection != .source {
                ForgeToggleRow(
                    title: L10n.preserveTone,
                    detail: L10n.proOption,
                    isOn: $model.preservesTone,
                    isLocked: !model.isProActive,
                    onLockedTap: { model.requiresPro = true }
                )
                if model.preservesTone {
                    ForgeMetricStepper(
                        title: L10n.saturation,
                        value: $model.saturation,
                        range: 0 ... 100,
                        step: 5,
                        valueLabel: "\(model.saturation)%"
                    )
                    ForgeMetricStepper(
                        title: L10n.lightness,
                        value: $model.lightness,
                        range: 0 ... 100,
                        step: 5,
                        valueLabel: "\(model.lightness)%"
                    )
                }
            }
        }
    }

    private var outlineControls: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
            ForgeLabeledControl(label: L10n.outline, isLocked: !model.isProActive) {
                ForgeSegmentedControl(
                    selection: $model.outlineMode,
                    options: [
                        ForgeSegmentOption(id: "none", value: .none, title: L10n.none),
                        ForgeSegmentOption(id: "black", value: .black, title: L10n.black),
                        ForgeSegmentOption(id: "adaptive", value: .adaptive, title: L10n.adaptive),
                    ]
                )
            }
            if model.outlineMode != .none {
                ForgeMetricStepper(
                    title: L10n.threshold,
                    value: $model.outlineThreshold,
                    range: 0 ... 100,
                    step: 5,
                    valueLabel: "\(model.outlineThreshold)"
                )
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if model.hasExistingRecord {
            ForgeButton(
                title: L10n.updateImage,
                icon: .render,
                role: .primary
            ) {
                model.convert(saveMode: .update)
            }
            ForgeButton(title: L10n.saveAsNew, icon: .plus) {
                model.convert(saveMode: .newRecord)
            }
        } else {
            ForgeButton(
                title: L10n.convert,
                icon: .render,
                role: .primary
            ) {
                model.convert(saveMode: .newRecord)
            }
        }
    }

    private var result: some View {
        VStack(spacing: ForgeDesign.Spacing.regular) {
            HStack(spacing: ForgeDesign.Spacing.regular) {
                ForgePreviewPane(
                    label: L10n.input,
                    metadata: model.sourceDimensionsLabel,
                    image: model.sourceImage,
                    pixelated: false,
                    emptyMessage: L10n.inputEmpty
                )
                ForgePreviewPane(
                    label: L10n.output,
                    metadata: model.outputDimensionsLabel,
                    image: model.outputImage,
                    pixelated: true,
                    emptyMessage: L10n.outputEmpty
                )
            }
            ForgeResultMetadata(
                logical: model.logicalDimensionsLabel,
                output: model.outputDimensionsLabel,
                algorithm: model.currentRecord?.metadata.algorithmVersion ?? PixelCoreInfo.algorithmVersion,
                paletteName: model.currentRecord?.metadata.paletteName ?? L10n.paletteSource
            )
            HStack(spacing: ForgeDesign.Spacing.compact) {
                ForgeButton(title: L10n.adjust, icon: .edit, fillsWidth: false) {
                    model.edit()
                }
                ForgeButton(
                    title: L10n.export,
                    icon: .export,
                    role: .primary,
                    fillsWidth: false
                ) {
                    model.export()
                }
            }
        }
        .padding(ForgeDesign.Spacing.roomy)
    }

    private var failure: some View {
        VStack(spacing: ForgeDesign.Spacing.regular) {
            ForgeSectionHeader(
                eyebrow: L10n.conversionFailed,
                title: L10n.previousImagePreserved,
                detail: model.errorMessage
            )
            ForgeButton(title: L10n.returnToSettings, icon: .restore, role: .primary, fillsWidth: false) {
                model.retry()
            }
        }
        .padding(ForgeDesign.Spacing.section)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var modalEyebrow: String {
        switch model.state {
        case .editing:
            L10n.stateEditing
        case .rendering:
            L10n.stateRendering
        case .result:
            L10n.stateResult
        case .failure:
            L10n.stateFailure
        }
    }

    private func captureReviewIfNeeded(for state: ConversionModalState) {
        guard state == .result, let reviewCaptureURL else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700))
            ReviewCapture.saveMainWindow(to: reviewCaptureURL)
        }
    }
}
