import AppKit
import PixelCoreKit
import SwiftUI
import UniformTypeIdentifiers

struct WorkbenchView: View {
    @StateObject private var model = WorkbenchModel()

    var body: some View {
        HStack(spacing: 0) {
            canvas
            recipePanel
        }
        .background(ForgeDesign.ColorToken.canvas)
        .foregroundStyle(ForgeDesign.ColorToken.ink)
        .fileImporter(
            isPresented: $model.isShowingImporter,
            allowedContentTypes: [.png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.load(url: url)
            }
        }
    }

    private var canvas: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(ForgeDesign.ColorToken.grid)
            HStack(spacing: ForgeDesign.Spacing.regular) {
                PreviewPane(
                    label: "INPUT",
                    metadata: model.sourceDimensions,
                    image: model.sourceImage,
                    pixelated: false,
                    emptyMessage: "写真を選ぶと、ここに元画像を表示します。"
                )
                PreviewPane(
                    label: "OUTPUT",
                    metadata: model.outputDimensions,
                    image: model.outputImage,
                    pixelated: true,
                    emptyMessage: "変換結果は補間せず、実際のピクセルで表示します。"
                )
            }
            .padding(ForgeDesign.Spacing.regular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: ForgeDesign.Spacing.regular) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Pixel Forge")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(model.sourceName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(ForgeDesign.ColorToken.muted)
                    .lineLimit(1)
            }
            Spacer()
            Button("写真を選ぶ") {
                model.isShowingImporter = true
            }
            .buttonStyle(ForgeSecondaryButtonStyle())
            .keyboardShortcut("o", modifiers: .command)
        }
        .padding(.horizontal, ForgeDesign.Spacing.roomy)
        .frame(height: 72)
    }

    private var recipePanel: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.roomy) {
            VStack(alignment: .leading, spacing: 4) {
                Text("レシピ")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text("同じ設定はCLIでも再現できます")
                    .font(.caption)
                    .foregroundStyle(ForgeDesign.ColorToken.muted)
            }

            VStack(spacing: ForgeDesign.Spacing.regular) {
                SettingStepper(title: "幅", value: $model.targetWidth, range: 8 ... 512, step: 8, suffix: "px")
                SettingStepper(title: "高さ", value: $model.targetHeight, range: 8 ... 512, step: 8, suffix: "px")
                SettingStepper(title: "色数", value: $model.colorCount, range: 2 ... 64, step: 1, suffix: "色")
                SettingStepper(title: "拡大", value: $model.upscale, range: 1 ... 32, step: 1, suffix: "×")
            }

            VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
                Text("ディザリング")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ForgeDesign.ColorToken.muted)
                Picker("ディザリング", selection: $model.dither) {
                    ForEach(PixelDitherMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(ForgeDesign.ColorToken.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button(model.isRendering ? "変換中…" : "変換する") {
                model.render()
            }
            .buttonStyle(ForgePrimaryButtonStyle())
            .disabled(model.sourceImage == nil || model.isRendering)

            Button("PNGとレシピを書き出す") {
                model.export()
            }
            .buttonStyle(ForgeSecondaryButtonStyle())
            .disabled(model.outputImage == nil || model.isRendering)
        }
        .padding(ForgeDesign.Spacing.roomy)
        .frame(width: ForgeDesign.recipeWidth)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(ForgeDesign.ColorToken.panel)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(ForgeDesign.ColorToken.grid)
                .frame(width: 1)
        }
    }
}

private struct PreviewPane: View {
    let label: String
    let metadata: String
    let image: NSImage?
    let pixelated: Bool
    let emptyMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeDesign.Spacing.compact) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                Spacer()
                Text(metadata)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(ForgeDesign.ColorToken.muted)
            }
            ZStack {
                PixelGridBackground()
                if let image {
                    if pixelated {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                    } else {
                        Image(nsImage: image)
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                    }
                } else {
                    VStack(spacing: ForgeDesign.Spacing.regular) {
                        Image(systemName: pixelated ? "squareshape.split.3x3" : "photo")
                            .font(.system(size: 28, weight: .light))
                        Text(emptyMessage)
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 220)
                    }
                    .foregroundStyle(ForgeDesign.ColorToken.muted)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ForgeDesign.Radius.canvas))
            .overlay {
                RoundedRectangle(cornerRadius: ForgeDesign.Radius.canvas)
                    .stroke(ForgeDesign.ColorToken.grid, lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PixelGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let cell: CGFloat = 16
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
                    context.fill(Path(rect), with: .color(ForgeDesign.ColorToken.grid.opacity(0.28)))
                }
            }
        }
        .background(ForgeDesign.ColorToken.surface)
    }
}

private struct SettingStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let suffix: String

    var body: some View {
        HStack {
            Text(title)
                .font(.callout)
            Spacer()
            Text(valueLabel)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(ForgeDesign.ColorToken.forge)
            Stepper(title, value: $value, in: range, step: step)
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(ForgeDesign.ColorToken.surface)
        .clipShape(RoundedRectangle(cornerRadius: ForgeDesign.Radius.control))
    }

    private var valueLabel: String {
        suffix == "×" ? "×\(value)" : "\(value) \(suffix)"
    }
}

private struct ForgePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.bold))
            .foregroundStyle(ForgeDesign.ColorToken.canvas)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(ForgeDesign.ColorToken.forge.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(RoundedRectangle(cornerRadius: ForgeDesign.Radius.control))
    }
}

private struct ForgeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(ForgeDesign.ColorToken.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .padding(.horizontal, ForgeDesign.Spacing.compact)
            .background(ForgeDesign.ColorToken.surface.opacity(configuration.isPressed ? 0.6 : 1))
            .overlay {
                RoundedRectangle(cornerRadius: ForgeDesign.Radius.control)
                    .stroke(ForgeDesign.ColorToken.grid, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: ForgeDesign.Radius.control))
    }
}
