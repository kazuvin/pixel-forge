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
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let valueLabel: String
    var isLocked = false

    var body: some View {
        HStack(spacing: ForgeDesign.Spacing.compact) {
            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.hairline) {
                Text(title)
                    .forgeTextStyle(.caption)
                    .foregroundStyle(palette.muted)
                if isLocked {
                    ForgeIcon(name: .lock, size: 12, colorRole: .accent)
                }
                Text(valueLabel)
                    .forgeTextStyle(.data)
                    .foregroundStyle(palette.ink)
                    .contentTransition(.numericText())
            }
            Spacer()
            ForgeStepButton(icon: .minus, isEnabled: value - step >= range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }
            ForgeStepButton(icon: .plus, isEnabled: value + step <= range.upperBound) {
                value = min(range.upperBound, value + step)
            }
        }
        .padding(.leading, ForgeDesign.Spacing.compact)
        .padding(.trailing, ForgeDesign.Spacing.tight)
        .frame(height: 58)
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
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
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
                Text(title)
                    .forgeTextStyle(.title)
                Text(detail)
                    .forgeTextStyle(.caption)
                    .foregroundStyle(palette.muted)
            }
            Spacer()
            ForgeIconButton(icon: .close, accessibilityLabel: L10n.close, action: close)
        }
        .padding(.horizontal, ForgeDesign.Spacing.regular)
        .frame(height: ForgeDesign.Size.toolbarHeight)
        .background(palette.panel)
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
        .background(palette.surface)
        .overlay { ForgePixelBorder(color: palette.grid) }
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
