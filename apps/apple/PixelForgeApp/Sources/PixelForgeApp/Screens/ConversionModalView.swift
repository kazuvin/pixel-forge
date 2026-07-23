import PixelCoreKit
import SwiftUI

struct ConversionModalView: View {
    @ObservedObject var model: ConversionSessionModel
    let close: () -> Void
    @State private var showsPalettePicker: Bool
    @State private var showsPresetLibrary: Bool
    @State private var showsStylePicker: Bool
    @State private var showsAdvancedSettings: Bool
    @State private var showsResultDeleteConfirmation = false
    @State private var showsOutputShareSheet = false
    @State private var outputShareItems: [Any] = []
    @State private var proRequirementMessage: String?
    private let loadsPresetsOnAppear: Bool

    init(
        model: ConversionSessionModel,
        opensPalettePicker: Bool = false,
        opensPresetLibrary: Bool = false,
        opensStylePicker: Bool = false,
        opensAdvancedSettings: Bool = false,
        close: @escaping () -> Void
    ) {
        self.model = model
        self.close = close
        loadsPresetsOnAppear = !opensPresetLibrary && !opensStylePicker
        _showsPalettePicker = State(initialValue: opensPalettePicker)
        _showsPresetLibrary = State(initialValue: opensPresetLibrary)
        _showsStylePicker = State(initialValue: opensStylePicker)
        _showsAdvancedSettings = State(initialValue: opensAdvancedSettings)
    }

    var body: some View {
        Group {
            if showsPalettePicker {
                PalettePickerView(model: model) {
                    showsPalettePicker = false
                }
            } else if showsPresetLibrary {
                RecipePresetLibraryView(model: model) {
                    showsPresetLibrary = false
                }
            } else if showsStylePicker {
                ConversionPresetPickerView(
                    model: model,
                    close: { showsStylePicker = false },
                    didSelect: {
                        showsAdvancedSettings = false
                        showsStylePicker = false
                    },
                    managePresets: {
                        showsStylePicker = false
                        showsPresetLibrary = true
                    }
                )
            } else {
                conversionScaffold
            }
        }
        .interactiveDismissDisabled(model.state == .rendering)
        .task {
            if loadsPresetsOnAppear {
                await model.loadPresets()
                model.refreshPreview(immediately: true)
            }
        }
        .onChange(of: model.state) { _, state in
            if state == .editing, model.currentStyleIsCustom {
                showsAdvancedSettings = true
            }
        }
        .onChange(of: model.longSide) { _, _ in model.settingsDidChange() }
        .onChange(of: model.upscale) { _, _ in model.settingsDidChange() }
        .onChange(of: model.paletteSelection) { _, _ in model.settingsDidChange() }
        .onChange(of: model.customPaletteColorValues) { _, _ in model.settingsDidChange() }
        .onChange(of: model.preservesTone) { _, _ in model.settingsDidChange() }
        .onChange(of: model.saturation) { _, _ in model.settingsDidChange() }
        .onChange(of: model.lightness) { _, _ in model.settingsDidChange() }
        .onChange(of: model.outlineMode) { _, _ in model.settingsDidChange() }
        .onChange(of: model.outlineThreshold) { _, _ in model.settingsDidChange() }
        .onChange(of: model.requiresPro) { _, isRequired in
            if isRequired {
                proRequirementMessage = L10n.proRequired
            }
        }
        .sheet(isPresented: $showsOutputShareSheet) {
            ActivitySheet(items: outputShareItems)
        }
        .forgeToast(message: $model.settingsCompatibilityWarning, style: .warning)
        .forgeToast(message: $proRequirementMessage, style: .warning)
        .forgeToast(message: $model.previewErrorMessage, style: .error)
        .forgeToast(message: transientErrorMessage, style: .error)
        .forgeToast(message: $model.duplicateMessage, style: .success)
        .forgeToast(message: photoSaveSuccessMessage, style: .success)
        .forgeToast(message: photoSaveErrorMessage, style: .error)
        .forgeToastContainer()
        .forgeOverlay {
            ForgeConfirmationDialog(
                isPresented: $showsResultDeleteConfirmation,
                eyebrow: L10n.deleteEyebrow,
                title: L10n.deleteTitle,
                detail: L10n.deleteDetail,
                confirmTitle: L10n.delete,
                cancelTitle: L10n.cancel
            ) {
                Task {
                    if await model.deleteCurrentRecord() {
                        close()
                    }
                }
            }
        }
    }

    private var conversionScaffold: some View {
        ForgeModalScaffold(
            eyebrow: modalEyebrow,
            title: model.sourceFilename,
            detail: model.sourceDimensionsLabel,
            close: close
        ) {
            modalContent
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
        VStack(spacing: 0) {
            ForgePreviewPane(
                label: L10n.output,
                metadata: model.isPreviewRendering ? L10n.rendering : model.outputDimensionsLabel,
                image: model.outputImage,
                pixelated: true,
                emptyMessage: L10n.outputEmpty
            )
            .frame(height: 214)
            .padding(.horizontal, ForgeDesign.Spacing.regular)
            .padding(.vertical, ForgeDesign.Spacing.compact)

            ForgeDivider()

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    ForgePixelSurface(level: .panel) {
                        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
                            adjustmentPresetBar
                            paletteRail
                            ForgeAdvancedSettingsDisclosure(
                                title: L10n.advancedSettingsTitle,
                                detail: L10n.advancedSettingsDetail,
                                isExpanded: $showsAdvancedSettings
                            )
                            if showsAdvancedSettings {
                                advancedSettings
                                    .id("advanced-settings")
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: showsAdvancedSettings)
                    .padding(ForgeDesign.Spacing.regular)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .scrollDismissesKeyboard(.interactively)
                .task {
                    if showsAdvancedSettings {
                        proxy.scrollTo("advanced-settings", anchor: .top)
                    }
                }
                .onChange(of: showsAdvancedSettings) { _, isExpanded in
                    guard isExpanded else { return }
                    Task { @MainActor in
                        await Task.yield()
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo("advanced-settings", anchor: .top)
                        }
                    }
                }
            }

            editorActionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var adjustmentPresetBar: some View {
        ForgeAdjustmentPresetBar(
            currentLabel: L10n.recipePresetCurrent,
            currentTitle: model.selectedConversionStyleTitle,
            loadTitle: L10n.recipePresetLoad,
            saveTitle: L10n.recipePresetSaveCompact,
            loadAccessibilityLabel: L10n.recipePresetLoad,
            saveAccessibilityLabel: L10n.recipePresetSave,
            load: {
                Task {
                    await model.loadPresets()
                    showsStylePicker = true
                }
            },
            save: {
                Task {
                    await model.loadPresets()
                    showsPresetLibrary = true
                }
            }
        )
    }

    private var paletteRail: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
            ForgeSectionHeader(
                eyebrow: L10n.paletteEyebrow,
                title: L10n.palette
            )
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: ForgeDesign.Spacing.compact) {
                    ForgeCompactPaletteCard(
                        title: L10n.paletteSource,
                        detail: L10n.paletteSourceCardDetail,
                        colors: [],
                        isSelected: model.paletteSelection == .source
                    ) {
                        model.paletteSelection = .source
                    }
                    ForgeCompactPaletteCard(
                        title: L10n.custom,
                        detail: L10n.compactPaletteColorCount(model.customPaletteColorValues.count),
                        colors: model.customPaletteColorValues,
                        isSelected: model.paletteSelection == .custom,
                        isLocked: !model.isProActive
                    ) {
                        model.paletteSelection = .custom
                        showsPalettePicker = true
                    }
                    ForEach(ConversionSessionModel.palettePresets) { preset in
                        ForgeCompactPaletteCard(
                            title: preset.displayName,
                            detail: L10n.compactPaletteColorCount(preset.colorValues.count),
                            colors: preset.colorValues,
                            isSelected: model.paletteSelection == .preset(preset.id),
                            isLocked: !model.isProActive
                        ) {
                            model.paletteSelection = .preset(preset.id)
                        }
                    }
                }
                .padding(.horizontal, ForgeDesign.Spacing.regular)
            }
            .padding(.horizontal, -ForgeDesign.Spacing.regular)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        }
    }

    private var advancedSettings: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
            ForgeSectionHeader(
                eyebrow: L10n.advancedSettingsEyebrow,
                title: L10n.advancedSettingsTitle,
                detail: L10n.advancedSettingsPanelDetail
            )
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
            if model.paletteSelection != .source {
                PaletteToneControls(model: model)
            }
            outlineControls
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
    private var editorActionBar: some View {
        if model.hasExistingRecord {
            ForgeConversionActionBar(
                primaryTitle: L10n.updateImage,
                primaryIcon: .render,
                primaryAction: { model.convert(saveMode: .update) },
                saveAsNew: { model.convert(saveMode: .newRecord) },
                saveToPhotos: { Task { await model.saveOutputToPhotos() } },
                share: shareOutput,
                duplicate: { Task { await model.duplicateCurrentRecord() } },
                delete: { showsResultDeleteConfirmation = true },
                isSaving: model.photoSaveState == .saving,
                hasOutput: model.outputImage != nil && !model.isPreviewRendering,
                isPrimaryEnabled: !model.isPreviewRendering
            )
        } else {
            ForgeConversionActionBar(
                primaryTitle: L10n.saveImage,
                primaryIcon: .render,
                primaryAction: { model.convert(saveMode: .newRecord) },
                saveToPhotos: { Task { await model.saveOutputToPhotos() } },
                share: shareOutput,
                isSaving: model.photoSaveState == .saving,
                hasOutput: model.outputImage != nil && !model.isPreviewRendering,
                isPrimaryEnabled: !model.isPreviewRendering
            )
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
                ForgeRecordActionPanel(
                    adjust: { model.edit() },
                    save: { Task { await model.saveOutputToPhotos() } },
                    share: shareOutput,
                    duplicate: { Task { await model.duplicateCurrentRecord() } },
                    delete: { showsResultDeleteConfirmation = true },
                    isSaving: model.photoSaveState == .saving
                )
            }
            .padding(ForgeDesign.Spacing.regular)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .vertical)
    }

    private func shareOutput() {
        guard let outputImage = model.outputImage else { return }
        outputShareItems = [outputImage]
        showsOutputShareSheet = true
    }

    private var transientErrorMessage: Binding<String?> {
        Binding(
            get: {
                model.state == .failure ? nil : model.errorMessage
            },
            set: { newValue in
                if model.state != .failure {
                    model.errorMessage = newValue
                }
            }
        )
    }

    private var photoSaveSuccessMessage: Binding<String?> {
        Binding(
            get: {
                model.photoSaveState == .saved ? L10n.photoSaveSuccess : nil
            },
            set: { newValue in
                if newValue == nil, model.photoSaveState == .saved {
                    model.photoSaveState = .idle
                }
            }
        )
    }

    private var photoSaveErrorMessage: Binding<String?> {
        Binding(
            get: {
                guard case let .failed(message) = model.photoSaveState else { return nil }
                return message
            },
            set: { newValue in
                if newValue == nil, case .failed = model.photoSaveState {
                    model.photoSaveState = .idle
                }
            }
        )
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
}

private struct ConversionPresetPickerView: View {
    @ObservedObject var model: ConversionSessionModel
    let close: () -> Void
    let didSelect: () -> Void
    let managePresets: () -> Void

    var body: some View {
        ForgeModalScaffold(
            eyebrow: L10n.conversionStyleEyebrow,
            title: L10n.conversionStylePickerTitle,
            detail: L10n.conversionStylePickerDetail,
            close: close
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: ForgeDesign.Spacing.section) {
                    builtInStyles
                    myPresets
                    ForgeButton(title: L10n.done, icon: .selected, role: .primary) {
                        close()
                    }
                }
                .padding(ForgeDesign.Spacing.regular)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
    }

    private var builtInStyles: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
            ForgeSectionHeader(
                eyebrow: L10n.conversionStyleBuiltInEyebrow,
                title: L10n.conversionStyleBuiltInTitle,
                detail: L10n.conversionStyleBuiltInDetail
            )
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: ForgeDesign.Spacing.compact
            ) {
                ForEach(ConversionSessionModel.conversionStylePresets) { preset in
                    ForgeConversionStyleCard(
                        title: preset.displayName,
                        detail: preset.displayDetail,
                        summary: model.settingsSummary(preset.settings),
                        colors: model.colorValues(for: preset.settings),
                        isSelected: model.isConversionStyleSelected(preset),
                        isLocked: !model.isProActive && model.conversionStyleRequiresPro(preset)
                    ) {
                        model.applyConversionStyle(preset)
                        didSelect()
                    }
                }
            }
        }
    }

    private var myPresets: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
            ForgeSectionHeader(
                eyebrow: L10n.recipePresetEyebrow,
                title: L10n.conversionStyleMyPresetsTitle,
                detail: L10n.conversionStyleMyPresetsDetail
            )
            if model.savedPresets.isEmpty {
                ForgePixelSurface(level: .surface, padding: ForgeDesign.Spacing.section) {
                    ForgeEmptyState(icon: .pixelGrid, message: L10n.recipePresetEmptyDetail)
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: ForgeDesign.Spacing.compact
                ) {
                    ForEach(model.savedPresets) { preset in
                        ForgeConversionStyleCard(
                            title: preset.name,
                            detail: L10n.conversionStyleSavedDetail,
                            summary: model.settingsSummary(preset.settings),
                            colors: model.colorValues(for: preset.settings),
                            isSelected: model.isSavedPresetSelected(preset),
                            isLocked: preset.algorithmVersion != PixelCoreInfo.algorithmVersion
                                || (!model.isProActive && model.savedPresetRequiresPro(preset))
                        ) {
                            model.applyPreset(preset)
                            didSelect()
                        }
                    }
                }
            }
            ForgeRecipePresetLibraryButton(
                title: L10n.recipePresetLibraryTitle,
                detail: L10n.recipePresetCount(model.savedPresets.count)
            ) {
                managePresets()
            }
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
        .forgeToast(message: $model.presetSuccessMessage, style: .success)
        .forgeToast(message: $model.presetErrorMessage, style: .error)
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
            }
        }
    }

    @ViewBuilder
    private var savedPresetList: some View {
        if model.savedPresets.isEmpty {
            ForgePixelSurface(level: .surface, padding: ForgeDesign.Spacing.section) {
                ForgeEmptyState(
                    icon: .pixelGrid,
                    message: L10n.recipePresetEmptyDetail,
                    eyebrow: L10n.recipePresetEyebrow,
                    title: L10n.recipePresetEmptyTitle
                )
            }
        } else {
            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
                ForEach(model.savedPresets) { preset in
                    ForgeRecipePresetCard(
                        title: preset.name,
                        detail: model.settingsSummary(preset.settings),
                        version: L10n.presetVersion(preset.algorithmVersion),
                        colors: model.colorValues(for: preset.settings),
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
                    if model.paletteSelection == .custom {
                        ForgeColorCollectionEditor(
                            colors: $model.customPaletteColorValues,
                            title: L10n.customPaletteColorsTitle,
                            detail: L10n.customPaletteColorsDetail,
                            addTitle: L10n.customPaletteAddColor,
                            deleteAccessibilityLabel: L10n.customPaletteDeleteColor
                        )
                    }
                    paletteGrid
                    if model.paletteSelection != .source {
                        PaletteToneControls(model: model)
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
        .onChange(of: model.customPaletteColorValues) { _, _ in model.refreshProRequirement() }
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
                ForgePaletteCard(
                    title: L10n.custom,
                    detail: L10n.paletteCustomCardDetail,
                    colors: model.customPaletteColorValues,
                    isSelected: model.paletteSelection == .custom,
                    isLocked: !model.isProActive
                ) {
                    model.paletteSelection = .custom
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
            }
        }
    }

}

private struct PaletteToneControls: View {
    @ObservedObject var model: ConversionSessionModel

    var body: some View {
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
