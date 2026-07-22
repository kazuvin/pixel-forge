import SwiftUI
import UIKit

struct ForgePixelChamferShape: Shape {
    var cut: CGFloat = ForgeDesign.Size.cornerCut

    func path(in rect: CGRect) -> Path {
        let cut = min(cut, rect.width / 2, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cut))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.maxX - cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cut, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cut))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cut))
        path.closeSubpath()
        return path
    }
}

struct ForgePixelBorder: View {
    let color: Color
    var cut: CGFloat = ForgeDesign.Size.cornerCut
    var lineWidth: CGFloat = ForgeDesign.Size.border

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let pixel = max(1, lineWidth)
            let cut = min(cut, (size.width / 2) - pixel, (size.height / 2) - pixel)
            let steps = max(1, Int((cut / pixel).rounded(.down)))
            var border = Path()

            border.addRect(
                CGRect(
                    x: cut + pixel,
                    y: 0,
                    width: max(0, size.width - (2 * (cut + pixel))),
                    height: lineWidth
                )
            )
            border.addRect(
                CGRect(
                    x: cut + pixel,
                    y: size.height - lineWidth,
                    width: max(0, size.width - (2 * (cut + pixel))),
                    height: lineWidth
                )
            )
            border.addRect(
                CGRect(
                    x: 0,
                    y: cut + pixel,
                    width: lineWidth,
                    height: max(0, size.height - (2 * (cut + pixel)))
                )
            )
            border.addRect(
                CGRect(
                    x: size.width - lineWidth,
                    y: cut + pixel,
                    width: lineWidth,
                    height: max(0, size.height - (2 * (cut + pixel)))
                )
            )

            for step in 0 ... steps {
                let offset = min(cut, CGFloat(step) * pixel)
                let inverse = cut - offset
                border.addRect(CGRect(x: offset, y: inverse, width: pixel, height: pixel))
                border.addRect(
                    CGRect(x: size.width - pixel - offset, y: inverse, width: pixel, height: pixel)
                )
                border.addRect(
                    CGRect(x: offset, y: size.height - pixel - inverse, width: pixel, height: pixel)
                )
                border.addRect(
                    CGRect(
                        x: size.width - pixel - offset,
                        y: size.height - pixel - inverse,
                        width: pixel,
                        height: pixel
                    )
                )
            }

            context.fill(border, with: .color(color))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ForgeCanvas<Content: View>: View {
    @Environment(\.forgePalette) private var palette
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            palette.canvas.ignoresSafeArea()
            content()
        }
        .foregroundStyle(palette.ink)
    }
}

extension View {
    func forgeOverlay<Overlay: View>(
        @ViewBuilder content: @escaping () -> Overlay
    ) -> some View {
        ZStack {
            self
            content()
        }
    }
}

struct ForgeDivider: View {
    @Environment(\.forgePalette) private var palette
    let axis: Axis

    init(_ axis: Axis = .horizontal) {
        self.axis = axis
    }

    var body: some View {
        Rectangle()
            .fill(palette.grid.opacity(0.72))
            .frame(
                width: axis == .vertical ? ForgeDesign.Size.border : nil,
                height: axis == .horizontal ? ForgeDesign.Size.border : nil
            )
    }
}

struct ForgeBrandMark: View {
    @Environment(\.forgePalette) private var palette

    var body: some View {
        ZStack {
            ForgePixelChamferShape(cut: ForgeDesign.Size.compactCornerCut)
                .fill(palette.surfaceRaised)
            ForgePixelBorder(color: palette.grid, cut: ForgeDesign.Size.compactCornerCut)
            Canvas { context, _ in
                let unit: CGFloat = 5
                let points = [
                    CGPoint(x: 9, y: 9),
                    CGPoint(x: 14, y: 9),
                    CGPoint(x: 19, y: 9),
                    CGPoint(x: 9, y: 14),
                    CGPoint(x: 19, y: 14),
                    CGPoint(x: 9, y: 19),
                    CGPoint(x: 14, y: 19),
                ]
                for point in points {
                    context.fill(
                        Path(CGRect(origin: point, size: CGSize(width: unit, height: unit))),
                        with: .color(palette.ink)
                    )
                }
                context.fill(
                    Path(CGRect(x: 19, y: 19, width: unit, height: unit)),
                    with: .color(palette.accent)
                )
            }
        }
        .frame(width: 34, height: 34)
        .accessibilityHidden(true)
    }
}

struct ForgeTopBar<Trailing: View>: View {
    @Environment(\.forgePalette) private var palette
    let eyebrow: String
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: () -> Trailing

    var body: some View {
        HStack(spacing: ForgeDesign.Spacing.regular) {
            ForgeBrandMark()
            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.hairline) {
                Text(eyebrow.uppercased())
                    .forgeTextStyle(.micro)
                    .foregroundStyle(palette.accent)
                Text(title)
                    .forgeTextStyle(.display)
                Text(subtitle)
                    .forgeTextStyle(.caption)
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: ForgeDesign.Spacing.regular)
            trailing()
        }
        .padding(.horizontal, ForgeDesign.Spacing.regular)
        .frame(height: ForgeDesign.Size.toolbarHeight)
        .background(palette.panel)
    }
}

enum ForgeButtonRole {
    case primary
    case secondary
}

struct ForgeButton: View {
    let title: String
    var icon: ForgeIconName?
    var role: ForgeButtonRole = .secondary
    var fillsWidth = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ForgeDesign.Spacing.tight) {
                if let icon {
                    ForgeIcon(
                        name: icon,
                        colorRole: role == .primary ? .accentInk : .ink
                    )
                }
                Text(title)
                    .forgeTextStyle(.body)
            }
        }
        .buttonStyle(ForgeButtonChrome(role: role, fillsWidth: fillsWidth))
    }
}

struct ForgeIconButton: View {
    let icon: ForgeIconName
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ForgeIcon(name: icon)
        }
        .buttonStyle(ForgeIconButtonChrome())
        .accessibilityLabel(accessibilityLabel)
    }
}

struct ForgeSettingsButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ForgeIcon(name: .sliders)
        }
        .buttonStyle(ForgeIconButtonChrome())
        .accessibilityLabel(label)
    }
}

private struct ForgeButtonChrome: ButtonStyle {
    @Environment(\.forgePalette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    let role: ForgeButtonRole
    let fillsWidth: Bool

    func makeBody(configuration: Configuration) -> some View {
        let isPrimary = role == .primary
        configuration.label
            .foregroundStyle(isPrimary ? palette.accentInk : palette.ink)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(height: ForgeDesign.Size.buttonHeight)
            .padding(.horizontal, fillsWidth ? 0 : ForgeDesign.Spacing.regular)
            .background {
                ForgePixelChamferShape()
                    .fill(isPrimary ? palette.accent : palette.surfaceRaised)
                    .opacity(configuration.isPressed ? 0.72 : 1)
            }
            .overlay {
                ForgePixelBorder(color: isPrimary ? palette.accent : palette.grid)
            }
            .opacity(isEnabled ? 1 : 0.38)
    }
}

private struct ForgeIconButtonChrome: ButtonStyle {
    @Environment(\.forgePalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(palette.ink)
            .frame(width: ForgeDesign.Size.controlHeight, height: ForgeDesign.Size.controlHeight)
            .background {
                ForgePixelChamferShape(cut: ForgeDesign.Size.compactCornerCut)
                    .fill(palette.surfaceRaised.opacity(configuration.isPressed ? 0.68 : 1))
            }
            .overlay {
                ForgePixelBorder(color: palette.grid, cut: ForgeDesign.Size.compactCornerCut)
            }
    }
}

enum ForgeSurfaceLevel {
    case panel
    case surface
    case raised
}

struct ForgePixelSurface<Content: View>: View {
    @Environment(\.forgePalette) private var palette
    let level: ForgeSurfaceLevel
    let isActive: Bool
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        level: ForgeSurfaceLevel = .surface,
        isActive: Bool = false,
        padding: CGFloat = ForgeDesign.Spacing.regular,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.level = level
        self.isActive = isActive
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .background {
                ForgePixelChamferShape()
                    .fill(fillColor)
            }
            .overlay {
                ForgePixelBorder(
                    color: isActive ? palette.accent : palette.grid,
                    lineWidth: isActive ? ForgeDesign.Size.activeBorder : ForgeDesign.Size.border
                )
            }
    }

    private var fillColor: Color {
        switch level {
        case .panel:
            palette.panel
        case .surface:
            palette.surface
        case .raised:
            palette.surfaceRaised
        }
    }
}

struct ForgeSectionHeader: View {
    @Environment(\.forgePalette) private var palette
    let eyebrow: String
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.tight) {
            HStack(spacing: ForgeDesign.Spacing.tight) {
                Rectangle()
                    .fill(palette.accent)
                    .frame(width: ForgeDesign.Size.statusLamp, height: ForgeDesign.Size.statusLamp)
                Text(eyebrow.uppercased())
                    .forgeTextStyle(.micro)
                    .foregroundStyle(palette.accent)
            }
            Text(title)
                .forgeTextStyle(.title)
            if let detail {
                Text(detail)
                    .forgeTextStyle(.caption)
                    .foregroundStyle(palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ForgeLabeledControl<Content: View>: View {
    @Environment(\.forgePalette) private var palette
    let label: String
    var isLocked = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
            HStack(spacing: ForgeDesign.Spacing.tight) {
                Text(label.uppercased())
                    .forgeTextStyle(.micro)
                    .foregroundStyle(palette.muted)
                if isLocked {
                    ForgeIcon(name: .lock, size: 12, colorRole: .accent)
                }
            }
            content()
        }
    }
}

struct ForgeAlertBanner: View {
    @Environment(\.forgePalette) private var palette
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: ForgeDesign.Spacing.compact) {
            Rectangle()
                .fill(palette.danger)
                .frame(width: ForgeDesign.Size.statusLamp, height: ForgeDesign.Size.statusLamp)
                .padding(.top, 3)
            Text(message)
                .forgeTextStyle(.caption)
                .foregroundStyle(palette.danger)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(ForgeDesign.Spacing.compact)
        .background(palette.danger.opacity(0.08))
        .overlay {
            Rectangle()
                .stroke(palette.danger.opacity(0.7), lineWidth: ForgeDesign.Size.border)
        }
    }
}

struct ForgeSuccessBanner: View {
    @Environment(\.forgePalette) private var palette
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: ForgeDesign.Spacing.compact) {
            Rectangle()
                .fill(palette.success)
                .frame(width: ForgeDesign.Size.statusLamp, height: ForgeDesign.Size.statusLamp)
                .padding(.top, 3)
            Text(message)
                .forgeTextStyle(.caption)
                .foregroundStyle(palette.success)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(ForgeDesign.Spacing.compact)
        .background(palette.success.opacity(0.08))
        .overlay {
            Rectangle()
                .stroke(palette.success.opacity(0.7), lineWidth: ForgeDesign.Size.border)
        }
    }
}

struct ForgeMetricStepper: View {
    @Environment(\.forgePalette) private var palette
    @FocusState private var isEditing
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let suffix: String
    var isLocked = false
    @State private var draft = ""

    var body: some View {
        VStack(spacing: ForgeDesign.Spacing.tight) {
            HStack(spacing: ForgeDesign.Spacing.compact) {
                HStack(spacing: ForgeDesign.Spacing.tight) {
                    Text(title)
                        .forgeTextStyle(.caption)
                        .foregroundStyle(palette.muted)
                    if isLocked {
                        ForgeIcon(name: .lock, size: 12, colorRole: .accent)
                    }
                }
                Spacer(minLength: 0)
                ForgeStepButton(icon: .minus, isEnabled: value > range.lowerBound) {
                    change(by: -step)
                }
                HStack(spacing: ForgeDesign.Spacing.hairline) {
                    TextField(String(value), text: $draft)
                        .focused($isEditing)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .forgeTextStyle(.data)
                        .frame(minWidth: 38, maxWidth: 62)
                        .onChange(of: draft) { _, newValue in
                            guard isEditing, let entered = Int(newValue) else { return }
                            value = min(range.upperBound, max(range.lowerBound, entered))
                        }
                    Text(suffix)
                        .forgeTextStyle(.caption)
                        .foregroundStyle(palette.muted)
                }
                .padding(.horizontal, ForgeDesign.Spacing.tight)
                .frame(height: ForgeDesign.Size.controlHeight)
                .background {
                    ForgePixelChamferShape(cut: ForgeDesign.Size.compactCornerCut)
                        .fill(palette.surfaceRaised)
                }
                .overlay {
                    ForgePixelBorder(color: palette.grid, cut: ForgeDesign.Size.compactCornerCut)
                }
                ForgeStepButton(icon: .plus, isEnabled: value < range.upperBound) {
                    change(by: step)
                }
            }
            ForgeScrubTrack(value: $value, range: range, step: step)
        }
        .padding(ForgeDesign.Spacing.compact)
        .background {
            ForgePixelChamferShape(cut: ForgeDesign.Size.compactCornerCut)
                .fill(palette.surface)
        }
        .overlay {
            ForgePixelBorder(
                color: palette.grid.opacity(0.74),
                cut: ForgeDesign.Size.compactCornerCut
            )
        }
        .onAppear { draft = String(value) }
        .onChange(of: value) { _, newValue in
            if !isEditing {
                draft = String(newValue)
            }
        }
        .onChange(of: isEditing) { _, editing in
            if !editing {
                draft = String(value)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(value) \(suffix)")
        .accessibilityAdjustableAction { direction in
            change(by: direction == .increment ? step : -step)
        }
    }

    private func change(by delta: Int) {
        value = min(range.upperBound, max(range.lowerBound, value + delta))
        draft = String(value)
    }
}

private struct ForgeStepButton: View {
    @Environment(\.forgePalette) private var palette
    let icon: ForgeIconName
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ForgeIcon(name: icon)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.ink)
        .frame(width: 44, height: 44)
        .background {
            ForgePixelChamferShape(cut: ForgeDesign.Size.compactCornerCut)
                .fill(palette.surfaceRaised)
        }
        .overlay {
            ForgePixelBorder(color: palette.grid, cut: ForgeDesign.Size.compactCornerCut)
        }
        .buttonRepeatBehavior(.enabled)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
    }
}

private struct ForgeScrubTrack: View {
    @Environment(\.forgePalette) private var palette
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    @State private var dragOrigin: Int?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(palette.grid.opacity(0.34))
                Rectangle()
                    .fill(palette.accent)
                    .frame(width: max(4, proxy.size.width * progress))
                Rectangle()
                    .fill(palette.accentInk)
                    .frame(width: 3)
                    .offset(x: max(0, min(proxy.size.width - 3, proxy.size.width * progress - 1.5)))
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard abs(gesture.translation.width) >= abs(gesture.translation.height) else {
                            return
                        }
                        if dragOrigin == nil {
                            dragOrigin = value
                        }
                        guard let dragOrigin else { return }
                        let steps = Int((gesture.translation.width / 12).rounded())
                        value = clamp(dragOrigin + (steps * step))
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }

    private var progress: CGFloat {
        guard range.upperBound > range.lowerBound else { return 0 }
        return CGFloat(value - range.lowerBound) / CGFloat(range.upperBound - range.lowerBound)
    }

    private func clamp(_ candidate: Int) -> Int {
        min(range.upperBound, max(range.lowerBound, candidate))
    }
}

struct ForgeSegmentOption<Value: Hashable>: Identifiable {
    let id: String
    let value: Value
    let title: String
}

struct ForgeSegmentedControl<Value: Hashable>: View {
    @Environment(\.forgePalette) private var palette
    @Binding var selection: Value
    let options: [ForgeSegmentOption<Value>]

    var body: some View {
        HStack(spacing: ForgeDesign.Spacing.hairline) {
            ForEach(options) { option in
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .forgeTextStyle(.caption)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(selection == option.value ? palette.accentInk : palette.muted)
                .background(selection == option.value ? palette.accent : palette.surface)
                .overlay {
                    Rectangle()
                        .stroke(
                            selection == option.value ? palette.accent : palette.grid.opacity(0.7),
                            lineWidth: ForgeDesign.Size.border
                        )
                }
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }
    }
}

enum ForgeOptionArtwork {
    case outlineNone
    case outlineBlack
    case outlineAdaptive
    case toneExact
    case tonePreserved
}

struct ForgeGraphicalOption<Value: Hashable>: Identifiable {
    let id: String
    let value: Value
    let title: String
    let artwork: ForgeOptionArtwork
    var isLocked = false
}

struct ForgeGraphicalOptionPicker<Value: Hashable>: View {
    @Environment(\.forgePalette) private var palette
    @Binding var selection: Value
    let options: [ForgeGraphicalOption<Value>]

    var body: some View {
        HStack(alignment: .top, spacing: ForgeDesign.Spacing.tight) {
            ForEach(options) { option in
                Button {
                    selection = option.value
                } label: {
                    VStack(spacing: ForgeDesign.Spacing.tight) {
                        ForgeOptionPreview(artwork: option.artwork)
                            .frame(height: 58)
                        Text(option.title)
                            .forgeTextStyle(.caption)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, minHeight: 34, alignment: .top)
                        ForgeIcon(
                            name: option.isLocked
                                ? .lock
                                : (selection == option.value ? .selected : .unselected),
                            size: 12,
                            colorRole: selection == option.value ? .accent : .muted
                        )
                    }
                    .padding(ForgeDesign.Spacing.tight)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    ForgePixelChamferShape(cut: ForgeDesign.Size.compactCornerCut)
                        .fill(selection == option.value ? palette.surfaceRaised : palette.surface)
                }
                .overlay {
                    ForgePixelBorder(
                        color: selection == option.value ? palette.accent : palette.grid,
                        cut: ForgeDesign.Size.compactCornerCut,
                        lineWidth: selection == option.value
                            ? ForgeDesign.Size.activeBorder
                            : ForgeDesign.Size.border
                    )
                }
                .accessibilityAddTraits(selection == option.value ? .isSelected : [])
            }
        }
    }
}

private struct ForgeOptionPreview: View {
    @Environment(\.forgePalette) private var palette
    let artwork: ForgeOptionArtwork

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let columns = 7
            let rows = 5
            let cell = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
            let origin = CGPoint(
                x: (size.width - CGFloat(columns) * cell) / 2,
                y: (size.height - CGFloat(rows) * cell) / 2
            )
            for row in 0 ..< rows {
                for column in 0 ..< columns {
                    let isShape = (1 ... 5).contains(column) && (1 ... 3).contains(row)
                    let isEdge = isShape && (column == 1 || column == 5 || row == 1 || row == 3)
                    let color: Color
                    switch artwork {
                    case .outlineNone:
                        color = isShape ? palette.accent : palette.surface
                    case .outlineBlack:
                        color = isEdge ? palette.ink : (isShape ? palette.accent : palette.surface)
                    case .outlineAdaptive:
                        color = isEdge ? palette.muted : (isShape ? palette.accent : palette.surface)
                    case .toneExact:
                        color = isShape
                            ? ((column + row).isMultiple(of: 2) ? palette.accent : palette.surfaceRaised)
                            : palette.surface
                    case .tonePreserved:
                        if !isShape {
                            color = palette.surface
                        } else if row == 1 {
                            color = palette.muted
                        } else if row == 2 {
                            color = palette.accent
                        } else {
                            color = palette.surfaceRaised
                        }
                    }
                    let rect = CGRect(
                        x: origin.x + CGFloat(column) * cell,
                        y: origin.y + CGFloat(row) * cell,
                        width: ceil(cell),
                        height: ceil(cell)
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .background(palette.surface)
        .overlay {
            ForgePixelBorder(color: palette.grid, cut: ForgeDesign.Size.compactCornerCut)
        }
    }
}

struct ForgePaletteSelectionButton: View {
    @Environment(\.forgePalette) private var palette
    let title: String
    let detail: String
    let colors: [UInt32]
    var isLocked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ForgeDesign.Spacing.regular) {
                ForgePaletteReferencePreview(colors: colors)
                    .frame(width: 92, height: 70)
                VStack(alignment: .leading, spacing: ForgeDesign.Spacing.tight) {
                    Text(title)
                        .forgeTextStyle(.heading)
                    Text(detail)
                        .forgeTextStyle(.caption)
                        .foregroundStyle(palette.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                ForgeIcon(name: isLocked ? .lock : .edit, colorRole: .accent)
            }
            .padding(ForgeDesign.Spacing.compact)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            ForgePixelChamferShape(cut: ForgeDesign.Size.compactCornerCut)
                .fill(palette.surface)
        }
        .overlay {
            ForgePixelBorder(color: palette.grid, cut: ForgeDesign.Size.compactCornerCut)
        }
    }
}

struct ForgeRecipePresetLibraryButton: View {
    @Environment(\.forgePalette) private var palette
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ForgeDesign.Spacing.regular) {
                ZStack {
                    ForgePixelChamferShape(cut: ForgeDesign.Size.compactCornerCut)
                        .fill(palette.surfaceRaised)
                    ForgeIcon(name: .pixelGrid, size: 24, colorRole: .accent)
                }
                .frame(width: 58, height: 58)
                .overlay {
                    ForgePixelBorder(color: palette.grid, cut: ForgeDesign.Size.compactCornerCut)
                }
                VStack(alignment: .leading, spacing: ForgeDesign.Spacing.tight) {
                    Text(title)
                        .forgeTextStyle(.heading)
                    Text(detail)
                        .forgeTextStyle(.caption)
                        .foregroundStyle(palette.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                ForgeIcon(name: .plus, colorRole: .accent)
            }
            .padding(ForgeDesign.Spacing.compact)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            ForgePixelChamferShape(cut: ForgeDesign.Size.compactCornerCut)
                .fill(palette.surface)
        }
        .overlay {
            ForgePixelBorder(color: palette.grid, cut: ForgeDesign.Size.compactCornerCut)
        }
    }
}

struct ForgeRecipePresetCard: View {
    @Environment(\.forgePalette) private var palette
    let title: String
    let detail: String
    let version: String
    let colors: [UInt32]
    let isCompatible: Bool
    let applyTitle: String
    let deleteAccessibilityLabel: String
    let apply: () -> Void
    let delete: () -> Void

    var body: some View {
        ForgePixelSurface(level: .surface) {
            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
                HStack(spacing: ForgeDesign.Spacing.regular) {
                    ForgePaletteReferencePreview(colors: colors)
                        .frame(width: 92, height: 70)
                    VStack(alignment: .leading, spacing: ForgeDesign.Spacing.tight) {
                        Text(title)
                            .forgeTextStyle(.heading)
                            .lineLimit(1)
                        Text(detail)
                            .forgeTextStyle(.caption)
                            .foregroundStyle(palette.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: ForgeDesign.Spacing.tight) {
                            Rectangle()
                                .fill(isCompatible ? palette.success : palette.danger)
                                .frame(
                                    width: ForgeDesign.Size.statusLamp,
                                    height: ForgeDesign.Size.statusLamp
                                )
                            Text(version)
                                .forgeTextStyle(.micro)
                                .foregroundStyle(palette.muted)
                        }
                    }
                    Spacer(minLength: 0)
                }
                ForgePaletteSwatches(colors: colors)
                    .frame(height: 12)
                HStack(spacing: ForgeDesign.Spacing.compact) {
                    ForgeButton(
                        title: applyTitle,
                        icon: isCompatible ? .selected : .restore,
                        role: .primary
                    ) {
                        apply()
                    }
                    ForgeIconButton(
                        icon: .trash,
                        accessibilityLabel: deleteAccessibilityLabel
                    ) {
                        delete()
                    }
                }
            }
        }
    }
}

struct ForgePaletteCard: View {
    @Environment(\.forgePalette) private var palette
    let title: String
    let detail: String
    let colors: [UInt32]
    let isSelected: Bool
    var isLocked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.tight) {
                ForgePaletteReferencePreview(colors: colors)
                    .frame(height: 92)
                Text(title)
                    .forgeTextStyle(.heading)
                    .lineLimit(1)
                Text(detail)
                    .forgeTextStyle(.caption)
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
                ForgePaletteSwatches(colors: colors)
                    .frame(height: 12)
                HStack {
                    Spacer()
                    ForgeIcon(
                        name: isLocked ? .lock : (isSelected ? .selected : .unselected),
                        size: 12,
                        colorRole: isSelected ? .accent : .muted
                    )
                }
            }
            .padding(ForgeDesign.Spacing.compact)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            ForgePixelChamferShape()
                .fill(isSelected ? palette.surfaceRaised : palette.surface)
        }
        .overlay {
            ForgePixelBorder(
                color: isSelected ? palette.accent : palette.grid,
                lineWidth: isSelected ? ForgeDesign.Size.activeBorder : ForgeDesign.Size.border
            )
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ForgePaletteReferencePreview: View {
    @Environment(\.forgePalette) private var palette
    let colors: [UInt32]

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let sample = colors.isEmpty ? [palette.muted, palette.surfaceRaised, palette.accent] : colors.map(forgePaletteColor)
            let columns = 8
            let rows = 6
            let cellWidth = size.width / CGFloat(columns)
            let cellHeight = size.height / CGFloat(rows)
            for row in 0 ..< rows {
                for column in 0 ..< columns {
                    let horizon = row < 2
                    let mountain = row == 2 && (column == 1 || column == 2 || column == 5)
                    let subject = (3 ... 5).contains(row) && (3 ... 4).contains(column)
                    let index: Int
                    if subject {
                        index = sample.count - 1
                    } else if mountain {
                        index = min(1, sample.count - 1)
                    } else if horizon {
                        index = 0
                    } else {
                        index = (row + column) % sample.count
                    }
                    let rect = CGRect(
                        x: CGFloat(column) * cellWidth,
                        y: CGFloat(row) * cellHeight,
                        width: ceil(cellWidth),
                        height: ceil(cellHeight)
                    )
                    context.fill(Path(rect), with: .color(sample[index]))
                }
            }
        }
        .background(palette.surface)
        .clipShape(ForgePixelChamferShape(cut: ForgeDesign.Size.compactCornerCut))
        .overlay {
            ForgePixelBorder(color: palette.grid, cut: ForgeDesign.Size.compactCornerCut)
        }
    }
}

private struct ForgePaletteSwatches: View {
    @Environment(\.forgePalette) private var palette
    let colors: [UInt32]

    var body: some View {
        HStack(spacing: ForgeDesign.Spacing.hairline) {
            ForEach(Array(colors.prefix(8).enumerated()), id: \.offset) { _, color in
                Rectangle()
                    .fill(forgePaletteColor(color))
                    .frame(maxWidth: .infinity)
            }
            if colors.isEmpty {
                Rectangle()
                    .fill(palette.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

private func forgePaletteColor(_ hex: UInt32) -> Color {
    Color(
        red: Double((hex >> 16) & 0xFF) / 255,
        green: Double((hex >> 8) & 0xFF) / 255,
        blue: Double(hex & 0xFF) / 255
    )
}

struct ForgeSidebar<Content: View>: View {
    @Environment(\.forgePalette) private var palette
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(ForgeDesign.Spacing.roomy)
            .frame(width: ForgeDesign.Size.recipeWidth)
            .frame(maxHeight: .infinity, alignment: .topLeading)
            .background(palette.panel)
            .overlay(alignment: .leading) {
                ForgeDivider(.vertical)
            }
    }
}

struct ForgePreviewPane: View {
    @Environment(\.forgePalette) private var palette
    let label: String
    let metadata: String
    let image: UIImage?
    let pixelated: Bool
    let emptyMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
            HStack(spacing: ForgeDesign.Spacing.compact) {
                Rectangle()
                    .fill(image == nil ? palette.grid : palette.accent)
                    .frame(width: ForgeDesign.Size.statusLamp, height: ForgeDesign.Size.statusLamp)
                Text(label.uppercased())
                    .forgeTextStyle(.caption)
                Spacer()
                Text(metadata)
                    .forgeTextStyle(.caption)
                    .foregroundStyle(palette.muted)
            }
            ZStack {
                ForgePixelGridBackground()
                if let image {
                    if pixelated {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                    } else {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                    }
                } else {
                    ForgeEmptyState(
                        icon: pixelated ? .pixelGrid : .photo,
                        message: emptyMessage
                    )
                }
            }
            .clipShape(ForgePixelChamferShape(cut: ForgeDesign.Size.previewCornerCut))
            .overlay {
                ForgePixelBorder(color: palette.grid, cut: ForgeDesign.Size.previewCornerCut)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ForgeEmptyState: View {
    @Environment(\.forgePalette) private var palette
    let icon: ForgeIconName
    let message: String

    var body: some View {
        VStack(spacing: ForgeDesign.Spacing.regular) {
            ForgeIcon(name: icon, size: 32, colorRole: .muted)
            Text(message)
                .forgeTextStyle(.body)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .foregroundStyle(palette.muted)
    }
}

struct ForgePixelGridBackground: View {
    @Environment(\.forgePalette) private var palette

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let cell: CGFloat = 18
            let columns = Int(ceil(size.width / cell))
            let rows = Int(ceil(size.height / cell))
            for row in 0 ..< rows {
                for column in 0 ..< columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * cell,
                        y: CGFloat(row) * cell,
                        width: cell,
                        height: cell
                    )
                    context.fill(Path(rect), with: .color(palette.grid.opacity(0.13)))
                }
            }
        }
        .background(palette.surface)
    }
}

struct ForgeStatusStrip: View {
    @Environment(\.forgePalette) private var palette
    let status: String
    let detail: String
    let trailing: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: ForgeDesign.Spacing.compact) {
            Rectangle()
                .fill(isActive ? palette.accent : palette.grid)
                .frame(width: ForgeDesign.Size.statusLamp, height: ForgeDesign.Size.statusLamp)
            Text(status.uppercased())
                .forgeTextStyle(.micro)
                .foregroundStyle(isActive ? palette.accent : palette.muted)
            ForgeDivider(.vertical)
                .frame(height: 14)
            Text(detail)
                .forgeTextStyle(.caption)
                .foregroundStyle(palette.muted)
                .lineLimit(1)
            Spacer()
            Text(trailing.uppercased())
                .forgeTextStyle(.micro)
                .foregroundStyle(palette.muted)
        }
        .padding(.horizontal, ForgeDesign.Spacing.regular)
        .frame(height: 38)
        .background(palette.panel)
    }
}

struct ForgeThemeCard: View {
    @Environment(\.forgePalette) private var currentPalette
    let theme: ForgeTheme
    let title: String
    let detail: String
    let isSelected: Bool
    var isLocked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ForgeDesign.Spacing.regular) {
                ForgeThemeSwatch(palette: theme.palette)
                VStack(alignment: .leading, spacing: ForgeDesign.Spacing.tight) {
                    Text(title)
                        .forgeTextStyle(.heading)
                        .foregroundStyle(currentPalette.ink)
                    Text(detail)
                        .forgeTextStyle(.caption)
                        .foregroundStyle(currentPalette.muted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                ForgeIcon(
                    name: isLocked ? .lock : (isSelected ? .selected : .unselected),
                    colorRole: isSelected ? .accent : .muted
                )
            }
            .padding(ForgeDesign.Spacing.regular)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            ForgePixelChamferShape()
                .fill(currentPalette.surface)
        }
        .overlay {
            ForgePixelBorder(
                color: isSelected ? currentPalette.accent : currentPalette.grid,
                lineWidth: isSelected ? ForgeDesign.Size.activeBorder : ForgeDesign.Size.border
            )
        }
    }
}

struct ForgeLibraryEmpty: View {
    @Environment(\.forgePalette) private var palette
    let title: String
    let detail: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        ForgePixelSurface(level: .surface, padding: ForgeDesign.Spacing.section) {
            VStack(spacing: ForgeDesign.Spacing.regular) {
                ForgeIcon(name: .addPhoto, size: 40, colorRole: .accent)
                Text(title)
                    .forgeTextStyle(.title)
                Text(detail)
                    .forgeTextStyle(.body)
                    .foregroundStyle(palette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                ForgeButton(title: actionTitle, icon: .addPhoto, role: .primary, fillsWidth: false) {
                    action()
                }
            }
        }
        .frame(maxWidth: 580)
    }
}

struct ForgeGeneratedCard: View {
    @Environment(\.forgePalette) private var palette
    let image: UIImage?
    let title: String
    let detail: String
    let updated: String
    let open: () -> Void
    let delete: () -> Void

    var body: some View {
        ForgePixelSurface(level: .surface, padding: 0) {
            VStack(spacing: 0) {
                Button(action: open) {
                    ZStack {
                        ForgePixelGridBackground()
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .padding(ForgeDesign.Spacing.compact)
                        }
                    }
                    .frame(height: 136)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                ForgeDivider()
                HStack(spacing: ForgeDesign.Spacing.compact) {
                    Button(action: open) {
                        HStack {
                            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.hairline) {
                                Text(title)
                                    .forgeTextStyle(.heading)
                                    .lineLimit(1)
                                Text(detail)
                                    .forgeTextStyle(.caption)
                                    .foregroundStyle(palette.muted)
                                Text(updated)
                                    .forgeTextStyle(.micro)
                                    .foregroundStyle(palette.muted)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    ForgeIconButton(icon: .trash, accessibilityLabel: L10n.delete) {
                        delete()
                    }
                }
                .padding(ForgeDesign.Spacing.compact)
            }
        }
    }
}

struct ForgeModalHeader: View {
    @Environment(\.forgePalette) private var palette
    let eyebrow: String
    let title: String
    let detail: String
    let close: () -> Void

    var body: some View {
        HStack(spacing: ForgeDesign.Spacing.regular) {
            ForgeBrandMark()
            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.hairline) {
                Text(eyebrow.uppercased())
                    .forgeTextStyle(.micro)
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                Text(title)
                    .forgeTextStyle(.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .forgeTextStyle(.caption)
                    .foregroundStyle(palette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
            ForgeIconButton(icon: .close, accessibilityLabel: L10n.close, action: close)
        }
        .padding(.horizontal, ForgeDesign.Spacing.regular)
        .frame(maxWidth: .infinity)
        .frame(height: ForgeDesign.Size.toolbarHeight)
        .background(palette.panel)
    }
}

struct ForgeModalScaffold<Content: View>: View {
    let eyebrow: String
    let title: String
    let detail: String
    let close: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        ForgeCanvas {
            VStack(spacing: 0) {
                ForgeModalHeader(
                    eyebrow: eyebrow,
                    title: title,
                    detail: detail,
                    close: close
                )
                ForgeDivider()
                content()
            }
            .padding(.top, ForgeDesign.Spacing.regular)
        }
    }
}

struct ForgeActionMenuItem: Identifiable {
    let id: String
    let title: String
    let icon: ForgeIconName
    let action: () -> Void
}

struct ForgeActionMenu: View {
    @Environment(\.forgePalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isPresented: Bool
    let eyebrow: String
    let title: String
    let items: [ForgeActionMenuItem]
    let cancelTitle: String
    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if isVisible {
                palette.canvas
                    .opacity(0.78)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }
                    .transition(.opacity)

                ForgePixelSurface(level: .raised) {
                    VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
                        ForgeSectionHeader(eyebrow: eyebrow, title: title)
                        ForEach(items) { item in
                            ForgeActionMenuRow(title: item.title, icon: item.icon) {
                                dismiss(then: item.action)
                            }
                        }
                        ForgeButton(title: cancelTitle, icon: .close) {
                            dismiss()
                        }
                    }
                }
                .frame(maxWidth: 340)
                .padding(.top, ForgeDesign.Size.toolbarHeight + ForgeDesign.Spacing.regular)
                .padding(.horizontal, ForgeDesign.Spacing.regular)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .scale(scale: 0.92, anchor: .topTrailing).combined(with: .opacity)
                )
                .accessibilityAddTraits(.isModal)
            }
        }
        .onAppear { setVisible(isPresented, animated: false) }
        .onChange(of: isPresented) { _, newValue in
            setVisible(newValue, animated: true)
        }
    }

    private func dismiss(then action: (() -> Void)? = nil) {
        setVisible(false, animated: true)
        action?()
        isPresented = false
    }

    private func setVisible(_ visible: Bool, animated: Bool) {
        guard animated, !reduceMotion else {
            isVisible = visible
            return
        }
        withAnimation(.spring(duration: 0.24, bounce: 0.14)) {
            isVisible = visible
        }
    }
}

struct ForgeConfirmationDialog: View {
    @Environment(\.forgePalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isPresented: Bool
    let eyebrow: String
    let title: String
    let detail: String
    let confirmTitle: String
    let cancelTitle: String
    let confirm: () -> Void
    @State private var isVisible = false

    var body: some View {
        ZStack {
            if isVisible {
                palette.canvas
                    .opacity(0.82)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { dismiss() }
                    .transition(.opacity)

                ForgePixelSurface(level: .raised) {
                    VStack(alignment: .leading, spacing: ForgeDesign.Spacing.regular) {
                        ForgeSectionHeader(eyebrow: eyebrow, title: title, detail: detail)
                        HStack(spacing: ForgeDesign.Spacing.compact) {
                            ForgeButton(title: cancelTitle, icon: .close) {
                                dismiss()
                            }
                            ForgeDestructiveButton(title: confirmTitle, icon: .trash) {
                                dismiss(then: confirm)
                            }
                        }
                    }
                }
                .frame(maxWidth: 360)
                .padding(ForgeDesign.Spacing.regular)
                .transition(
                    reduceMotion
                        ? .opacity
                        : .scale(scale: 0.9, anchor: .center).combined(with: .opacity)
                )
                .accessibilityAddTraits(.isModal)
            }
        }
        .onAppear { setVisible(isPresented, animated: false) }
        .onChange(of: isPresented) { _, newValue in
            setVisible(newValue, animated: true)
        }
    }

    private func dismiss(then action: (() -> Void)? = nil) {
        setVisible(false, animated: true)
        action?()
        isPresented = false
    }

    private func setVisible(_ visible: Bool, animated: Bool) {
        guard animated, !reduceMotion else {
            isVisible = visible
            return
        }
        withAnimation(.spring(duration: 0.22, bounce: 0.1)) {
            isVisible = visible
        }
    }
}

private struct ForgeActionMenuRow: View {
    @Environment(\.forgePalette) private var palette
    let title: String
    let icon: ForgeIconName
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ForgeDesign.Spacing.compact) {
                ForgeIcon(name: icon, colorRole: .accent)
                Text(title)
                    .forgeTextStyle(.body)
                Spacer()
                ForgeIcon(name: .plus, size: 12, colorRole: .muted)
            }
            .padding(.horizontal, ForgeDesign.Spacing.compact)
            .frame(minHeight: ForgeDesign.Size.controlHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background {
            ForgePixelChamferShape(cut: ForgeDesign.Size.compactCornerCut)
                .fill(palette.surface)
        }
        .overlay {
            ForgePixelBorder(color: palette.grid, cut: ForgeDesign.Size.compactCornerCut)
        }
    }
}

private struct ForgeDestructiveButton: View {
    @Environment(\.forgePalette) private var palette
    let title: String
    let icon: ForgeIconName
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ForgeDesign.Spacing.tight) {
                ForgeIcon(name: icon, colorRole: .accentInk)
                Text(title)
                    .forgeTextStyle(.body)
            }
            .frame(maxWidth: .infinity)
            .frame(height: ForgeDesign.Size.buttonHeight)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.accentInk)
        .background {
            ForgePixelChamferShape()
                .fill(palette.danger)
        }
        .overlay { ForgePixelBorder(color: palette.danger) }
    }
}

struct ForgeToggleRow: View {
    @Environment(\.forgePalette) private var palette
    let title: String
    let detail: String?
    @Binding var isOn: Bool
    var isLocked = false
    var onLockedTap: (() -> Void)?

    var body: some View {
        Button {
            if isLocked {
                onLockedTap?()
            } else {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: ForgeDesign.Spacing.compact) {
                VStack(alignment: .leading, spacing: ForgeDesign.Spacing.hairline) {
                    Text(title)
                        .forgeTextStyle(.body)
                    if let detail {
                        Text(detail)
                            .forgeTextStyle(.caption)
                            .foregroundStyle(palette.muted)
                    }
                }
                Spacer()
                ForgeIcon(
                    name: isLocked ? .lock : (isOn ? .selected : .unselected),
                    colorRole: isOn ? .accent : .muted
                )
            }
            .padding(ForgeDesign.Spacing.compact)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(palette.surface)
        .overlay {
            ForgePixelBorder(color: isOn ? palette.accent : palette.grid)
        }
    }
}

struct ForgeTextInput: View {
    @Environment(\.forgePalette) private var palette
    let label: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.tight) {
            Text(label.uppercased())
                .forgeTextStyle(.micro)
                .foregroundStyle(palette.muted)
            TextField(label, text: $text)
                .textFieldStyle(.plain)
                .forgeTextStyle(.data)
                .padding(ForgeDesign.Spacing.compact)
                .background(palette.surface)
                .overlay {
                    ForgePixelBorder(color: palette.grid)
                }
        }
    }
}

struct ForgeConversionLoading: View {
    @Environment(\.forgePalette) private var palette
    let isVisible: Bool
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: ForgeDesign.Spacing.regular) {
            if isVisible {
                ProgressView()
                    .controlSize(.large)
                    .tint(palette.accent)
                Text(title)
                    .forgeTextStyle(.title)
                Text(detail)
                    .forgeTextStyle(.body)
                    .foregroundStyle(palette.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ForgeResultMetadata: View {
    @Environment(\.forgePalette) private var palette
    let logical: String
    let output: String
    let algorithm: String
    let paletteName: String

    var body: some View {
        ForgePixelSurface(level: .raised, padding: ForgeDesign.Spacing.compact) {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: ForgeDesign.Spacing.compact
            ) {
                item(L10n.logicalSize, logical)
                item(L10n.outputSize, output)
                item(L10n.palette, paletteName)
                item(L10n.algorithm, algorithm)
            }
        }
    }

    private func item(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.hairline) {
            Text(title.uppercased())
                .forgeTextStyle(.micro)
                .foregroundStyle(palette.muted)
            Text(value)
                .forgeTextStyle(.data)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ForgeSettingsLinkRow: View {
    @Environment(\.forgePalette) private var palette
    let title: String
    let detail: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ForgeDesign.Spacing.compact) {
                VStack(alignment: .leading, spacing: ForgeDesign.Spacing.hairline) {
                    Text(title)
                        .forgeTextStyle(.body)
                    if let detail {
                        Text(detail)
                            .forgeTextStyle(.caption)
                            .foregroundStyle(palette.muted)
                    }
                }
                Spacer()
                ForgeIcon(name: .link, colorRole: .muted)
            }
            .padding(ForgeDesign.Spacing.compact)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(palette.surface)
        .overlay { ForgePixelBorder(color: palette.grid) }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
    }
}

struct ForgeProPanel: View {
    @Environment(\.forgePalette) private var palette
    let title: String
    let detail: String
    let status: String
    let purchaseTitle: String
    let restoreTitle: String
    let canPurchase: Bool
    let purchase: () -> Void
    let restore: () -> Void

    var body: some View {
        ForgePixelSurface(level: .raised) {
            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
                HStack {
                    ForgeIcon(name: .lock, colorRole: .accent)
                    Text(title)
                        .forgeTextStyle(.heading)
                    Spacer()
                    Text(status.uppercased())
                        .forgeTextStyle(.micro)
                        .foregroundStyle(palette.accent)
                }
                Text(detail)
                    .forgeTextStyle(.caption)
                    .foregroundStyle(palette.muted)
                HStack(spacing: ForgeDesign.Spacing.compact) {
                    ForgeButton(
                        title: purchaseTitle,
                        icon: .lock,
                        role: .primary,
                        fillsWidth: false,
                        action: purchase
                    )
                    .disabled(!canPurchase)
                    ForgeButton(
                        title: restoreTitle,
                        icon: .restore,
                        fillsWidth: false,
                        action: restore
                    )
                }
            }
        }
    }
}

struct ForgeAboutRow: View {
    @Environment(\.forgePalette) private var palette
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .forgeTextStyle(.body)
            Spacer()
            Text(value)
                .forgeTextStyle(.data)
                .foregroundStyle(palette.muted)
        }
        .padding(ForgeDesign.Spacing.compact)
        .background(palette.surface)
        .overlay { ForgePixelBorder(color: palette.grid) }
    }
}

struct ForgeTypographySample: View {
    @Environment(\.forgePalette) private var palette
    let sample: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.tight) {
            Text(sample)
                .forgeTextStyle(.title)
            Text(detail)
                .forgeTextStyle(.caption)
                .foregroundStyle(palette.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ForgeDesign.Spacing.regular)
        .background(palette.surface)
        .overlay {
            ForgePixelBorder(color: palette.grid)
        }
        .clipShape(ForgePixelChamferShape())
    }
}

private struct ForgeThemeSwatch: View {
    let palette: ForgePalette

    var body: some View {
        ZStack {
            ForgePixelChamferShape(cut: ForgeDesign.Size.compactCornerCut)
                .fill(palette.canvas)
            VStack(spacing: 4) {
                Rectangle()
                    .fill(palette.ink)
                    .frame(width: 28, height: 5)
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(palette.accent)
                    Rectangle()
                        .fill(palette.surfaceRaised)
                }
                .frame(width: 28, height: 14)
            }
        }
        .overlay {
            ForgePixelBorder(color: palette.grid, cut: ForgeDesign.Size.compactCornerCut)
        }
        .frame(width: 54, height: 54)
    }
}
