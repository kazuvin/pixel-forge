import PixelCoreKit
import SwiftUI

struct ConversionModalView: View {
    @ObservedObject var model: ConversionSessionModel
    let close: () -> Void
    @State private var showsPalettePicker: Bool
    @State private var showsPresetLibrary: Bool
    private let loadsPresetsOnAppear: Bool

    init(
        model: ConversionSessionModel,
        opensPalettePicker: Bool = false,
        opensPresetLibrary: Bool = false,
        close: @escaping () -> Void
    ) {
        self.model = model
        self.close = close
        loadsPresetsOnAppear = !opensPresetLibrary
        _showsPalettePicker = State(initialValue: opensPalettePicker)
        _showsPresetLibrary = State(initialValue: opensPresetLibrary)
    }

    var body: some View {
        ForgeModalScaffold(
            eyebrow: modalEyebrow,
            title: model.sourceFilename,
            detail: model.sourceDimensionsLabel,
            close: close
        ) {
            modalContent
        }
        .interactiveDismissDisabled(model.state == .rendering)
        .fullScreenCover(isPresented: $showsPalettePicker) {
            PalettePickerView(model: model) {
                showsPalettePicker = false
            }
        }
        .fullScreenCover(isPresented: $showsPresetLibrary) {
            RecipePresetLibraryView(model: model) {
                showsPresetLibrary = false
            }
        }
        .task {
            if loadsPresetsOnAppear {
                await model.loadPresets()
            }
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
                ForgePreviewPane(
                    label: L10n.input,
                    metadata: model.sourceDimensionsLabel,
                    image: model.sourceImage,
                    pixelated: false,
                    emptyMessage: L10n.inputEmpty
                )
                .frame(height: 260)

                ForgePixelSurface(level: .panel) {
                    VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
                        ForgeSectionHeader(
                            eyebrow: L10n.recipeEyebrow,
                            title: L10n.conversionOptions,
                            detail: L10n.conversionOptionsDetail
                        )
                        if let warning = model.settingsCompatibilityWarning {
                            ForgeAlertBanner(message: warning)
                        }
                        ForgeRecipePresetLibraryButton(
                            title: L10n.recipePresetTitle,
                            detail: L10n.recipePresetCount(model.savedPresets.count)
                        ) {
                            Task {
                                await model.loadPresets()
                                showsPresetLibrary = true
                            }
                        }
                        ForgeMetricStepper(
                            title: L10n.longSide,
                            value: $model.longSide,
                            range: 1 ... 1024,
                            step: 1,
                            suffix: "px",
                            isLocked: !model.isProActive
                        )
                        ForgeMetricStepper(
                            title: L10n.upscale,
                            value: $model.upscale,
                            range: 1 ... 32,
                            step: 1,
                            suffix: "×",
                            isLocked: !model.isProActive
                        )
                        paletteControl
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
                .onChange(of: model.longSide) { _, _ in model.refreshProRequirement() }
                .onChange(of: model.upscale) { _, _ in model.refreshProRequirement() }
                .onChange(of: model.paletteSelection) { _, _ in model.refreshProRequirement() }
                .onChange(of: model.preservesTone) { _, _ in model.refreshProRequirement() }
                .onChange(of: model.outlineMode) { _, _ in model.refreshProRequirement() }
            }
            .padding(ForgeDesign.Spacing.regular)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        .scrollDismissesKeyboard(.interactively)
    }

    private var paletteControl: some View {
        ForgeLabeledControl(
            label: L10n.palette,
            isLocked: !model.isProActive && model.paletteSelection != .source
        ) {
            ForgePaletteSelectionButton(
                title: model.selectedPaletteTitle,
                detail: selectedPaletteDetail,
                colors: model.selectedPaletteColorValues,
                isLocked: !model.isProActive && model.paletteSelection != .source
            ) {
                showsPalettePicker = true
            }
        }
    }

    private var outlineControls: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
            ForgeLabeledControl(label: L10n.outline, isLocked: !model.isProActive) {
                ForgeGraphicalOptionPicker(
                    selection: $model.outlineMode,
                    options: [
                        ForgeGraphicalOption(
                            id: "none",
                            value: .none,
                            title: L10n.none,
                            artwork: .outlineNone
                        ),
                        ForgeGraphicalOption(
                            id: "black",
                            value: .black,
                            title: L10n.black,
                            artwork: .outlineBlack,
                            isLocked: !model.isProActive
                        ),
                        ForgeGraphicalOption(
                            id: "adaptive",
                            value: .adaptive,
                            title: L10n.adaptive,
                            artwork: .outlineAdaptive,
                            isLocked: !model.isProActive
                        ),
                    ]
                )
            }
            if model.outlineMode != .none {
                ForgeMetricStepper(
                    title: L10n.threshold,
                    value: $model.outlineThreshold,
                    range: 0 ... 100,
                    step: 5,
                    suffix: "%",
                    isLocked: !model.isProActive
                )
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if model.hasExistingRecord {
            ForgeButton(title: L10n.updateImage, icon: .render, role: .primary) {
                model.convert(saveMode: .update)
            }
            ForgeButton(title: L10n.saveAsNew, icon: .plus) {
                model.convert(saveMode: .newRecord)
            }
        } else {
            ForgeButton(title: L10n.convert, icon: .render, role: .primary) {
                model.convert(saveMode: .newRecord)
            }
        }
    }

    private var result: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: ForgeDesign.Spacing.regular) {
                ForgePreviewPane(
                    label: L10n.input,
                    metadata: model.sourceDimensionsLabel,
                    image: model.sourceImage,
                    pixelated: false,
                    emptyMessage: L10n.inputEmpty
                )
                .frame(height: 240)
                ForgePreviewPane(
                    label: L10n.output,
                    metadata: model.outputDimensionsLabel,
                    image: model.outputImage,
                    pixelated: true,
                    emptyMessage: L10n.outputEmpty
                )
                .frame(height: 240)
                ForgeResultMetadata(
                    logical: model.logicalDimensionsLabel,
                    output: model.outputDimensionsLabel,
                    algorithm: model.currentRecord?.metadata.algorithmVersion ?? PixelCoreInfo.algorithmVersion,
                    paletteName: model.currentRecord?.metadata.paletteName ?? L10n.paletteSource
                )
                switch model.photoSaveState {
                case .idle, .saving:
                    EmptyView()
                case .saved:
                    ForgeSuccessBanner(message: L10n.photoSaveSuccess)
                case let .failed(message):
                    ForgeAlertBanner(message: message)
                }
                HStack(spacing: ForgeDesign.Spacing.compact) {
                    ForgeButton(title: L10n.adjust, icon: .edit) {
                        model.edit()
                    }
                    ForgeButton(
                        title: model.photoSaveState == .saving
                            ? L10n.savingToPhotos
                            : L10n.saveToPhotos,
                        icon: .savePhoto,
                        role: .primary
                    ) {
                        Task { await model.saveOutputToPhotos() }
                    }
                    .disabled(model.photoSaveState == .saving)
                }
            }
            .padding(ForgeDesign.Spacing.regular)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
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

    private var selectedPaletteDetail: String {
        if model.paletteSelection == .source {
            return L10n.paletteSourceDetail
        }
        return L10n.paletteColorCount(model.selectedPaletteColorValues.count)
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
}

private struct RecipePresetLibraryView: View {
    @ObservedObject var model: ConversionSessionModel
    let close: () -> Void
    @State private var presetName = ""
    @State private var pendingDeletion: SavedConversionPreset?

    var body: some View {
        ForgeModalScaffold(
            eyebrow: L10n.recipePresetEyebrow,
            title: L10n.recipePresetLibraryTitle,
            detail: L10n.recipePresetLibraryDetail,
            close: close
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: ForgeDesign.Spacing.section) {
                    savePanel
                    savedPresetList
                }
                .padding(ForgeDesign.Spacing.regular)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollDismissesKeyboard(.interactively)
        }
        .forgeOverlay {
            ForgeConfirmationDialog(
                isPresented: deletionIsPresented,
                eyebrow: L10n.presetDeleteEyebrow,
                title: L10n.presetDeleteTitle,
                detail: L10n.presetDeleteDetail,
                confirmTitle: L10n.delete,
                cancelTitle: L10n.cancel
            ) {
                guard let pendingDeletion else { return }
                Task { await model.deletePreset(pendingDeletion) }
                self.pendingDeletion = nil
            }
        }
    }

    private var savePanel: some View {
        ForgePixelSurface(level: .panel) {
            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
                ForgeSectionHeader(
                    eyebrow: L10n.recipePresetEyebrow,
                    title: L10n.recipePresetTitle,
                    detail: L10n.recipePresetDetail
                )
                ForgeTextInput(label: L10n.recipePresetName, text: $presetName)
                ForgeButton(
                    title: L10n.recipePresetSave,
                    icon: .plus,
                    role: .primary
                ) {
                    Task {
                        if await model.saveCurrentPreset(named: presetName) {
                            presetName = ""
                        }
                    }
                }
                if let message = model.presetSuccessMessage {
                    ForgeSuccessBanner(message: message)
                }
                if let message = model.presetErrorMessage {
                    ForgeAlertBanner(message: message)
                }
            }
        }
    }

    @ViewBuilder
    private var savedPresetList: some View {
        if model.savedPresets.isEmpty {
            ForgePixelSurface(level: .surface, padding: ForgeDesign.Spacing.section) {
                VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
                    ForgeSectionHeader(
                        eyebrow: L10n.recipePresetEyebrow,
                        title: L10n.recipePresetEmptyTitle,
                        detail: nil
                    )
                    ForgeEmptyState(icon: .pixelGrid, message: L10n.recipePresetEmptyDetail)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
                ForEach(model.savedPresets) { preset in
                    ForgeRecipePresetCard(
                        title: preset.name,
                        detail: summary(for: preset.settings),
                        version: L10n.presetVersion(preset.algorithmVersion),
                        colors: colors(for: preset.settings),
                        isCompatible: preset.algorithmVersion == PixelCoreInfo.algorithmVersion,
                        applyTitle: L10n.recipePresetApply,
                        deleteAccessibilityLabel: L10n.delete,
                        apply: {
                            model.applyPreset(preset)
                            close()
                        },
                        delete: {
                            pendingDeletion = preset
                        }
                    )
                }
            }
        }
    }

    private var deletionIsPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeletion = nil
                }
            }
        )
    }

    private func summary(for settings: PixelConversionSettings) -> String {
        L10n.presetSummary(
            Int(settings.longSide),
            Int(settings.upscale),
            paletteTitle(for: settings)
        )
    }

    private func paletteTitle(for settings: PixelConversionSettings) -> String {
        switch settings.colorMode {
        case .source:
            L10n.paletteSource
        case let .palette(palette, _):
            ConversionSessionModel.palettePresets
                .first(where: { $0.name == palette.name })?.displayName ?? palette.name
        }
    }

    private func colors(for settings: PixelConversionSettings) -> [UInt32] {
        guard case let .palette(palette, _) = settings.colorMode else { return [] }
        return palette.colors.map {
            UInt32($0.red) << 16 | UInt32($0.green) << 8 | UInt32($0.blue)
        }
    }
}

private struct PalettePickerView: View {
    @ObservedObject var model: ConversionSessionModel
    let close: () -> Void

    var body: some View {
        ForgeModalScaffold(
            eyebrow: L10n.paletteEyebrow,
            title: L10n.palettePickerTitle,
            detail: L10n.palettePickerDetail,
            close: close
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: ForgeDesign.Spacing.section) {
                    paletteGrid
                    if model.paletteSelection == .custom {
                        ForgeTextInput(label: L10n.customPalette, text: $model.customPaletteText)
                    }
                    if model.paletteSelection != .source {
                        toneControls
                    }
                    if model.requiresPro {
                        ForgeAlertBanner(message: L10n.proRequired)
                    }
                    ForgeButton(title: L10n.done, icon: .selected, role: .primary) {
                        close()
                    }
                }
                .padding(ForgeDesign.Spacing.regular)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .scrollDismissesKeyboard(.interactively)
        }
        .onChange(of: model.paletteSelection) { _, _ in model.refreshProRequirement() }
        .onChange(of: model.customPaletteText) { _, _ in model.refreshProRequirement() }
        .onChange(of: model.preservesTone) { _, _ in model.refreshProRequirement() }
        .onChange(of: model.saturation) { _, _ in model.refreshProRequirement() }
        .onChange(of: model.lightness) { _, _ in model.refreshProRequirement() }
    }

    private var paletteGrid: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
            ForgeSectionHeader(
                eyebrow: L10n.paletteCollectionEyebrow,
                title: L10n.paletteCollectionTitle,
                detail: L10n.paletteCollectionDetail
            )
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: ForgeDesign.Spacing.compact
            ) {
                ForgePaletteCard(
                    title: L10n.paletteSource,
                    detail: L10n.paletteSourceCardDetail,
                    colors: [],
                    isSelected: model.paletteSelection == .source
                ) {
                    model.paletteSelection = .source
                }
                ForEach(ConversionSessionModel.palettePresets) { preset in
                    ForgePaletteCard(
                        title: preset.displayName,
                        detail: L10n.paletteColorCount(preset.colorValues.count),
                        colors: preset.colorValues,
                        isSelected: model.paletteSelection == .preset(preset.id),
                        isLocked: !model.isProActive
                    ) {
                        model.paletteSelection = .preset(preset.id)
                    }
                }
                ForgePaletteCard(
                    title: L10n.custom,
                    detail: L10n.paletteCustomCardDetail,
                    colors: model.customPaletteColorValues,
                    isSelected: model.paletteSelection == .custom,
                    isLocked: !model.isProActive
                ) {
                    model.paletteSelection = .custom
                }
            }
        }
    }

    private var toneControls: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
            ForgeSectionHeader(
                eyebrow: L10n.paletteApplicationEyebrow,
                title: L10n.paletteApplicationTitle,
                detail: L10n.paletteApplicationDetail
            )
            ForgeGraphicalOptionPicker(
                selection: $model.preservesTone,
                options: [
                    ForgeGraphicalOption(
                        id: "exact",
                        value: false,
                        title: L10n.paletteExact,
                        artwork: .toneExact,
                        isLocked: !model.isProActive
                    ),
                    ForgeGraphicalOption(
                        id: "preserve-tone",
                        value: true,
                        title: L10n.preserveTone,
                        artwork: .tonePreserved,
                        isLocked: !model.isProActive
                    ),
                ]
            )
            if model.preservesTone {
                ForgeMetricStepper(
                    title: L10n.saturation,
                    value: $model.saturation,
                    range: 0 ... 100,
                    step: 5,
                    suffix: "%",
                    isLocked: !model.isProActive
                )
                ForgeMetricStepper(
                    title: L10n.lightness,
                    value: $model.lightness,
                    range: 0 ... 100,
                    step: 5,
                    suffix: "%",
                    isLocked: !model.isProActive
                )
            }
        }
    }
}
