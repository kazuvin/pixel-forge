import CoreText
import SwiftUI

enum ForgeFont {
    static let postScriptName = "DotGothic16-Regular"

    private static let registration: Void = {
        let appBundle = Bundle(for: ForgeFontBundleToken.self)
        let bundledURL = appBundle.url(
            forResource: "DotGothic16-Regular",
            withExtension: "ttf",
            subdirectory: "Fonts"
        ) ?? appBundle.url(forResource: "DotGothic16-Regular", withExtension: "ttf")

        guard let bundledURL else { return }
        CTFontManagerRegisterFontsForURL(bundledURL as CFURL, .process, nil)
    }()

    static func registerBundledFonts() {
        _ = registration
    }

    static func font(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        .custom(postScriptName, size: size, relativeTo: style)
    }
}

private final class ForgeFontBundleToken {}

enum ForgeTextStyle {
    case display
    case title
    case heading
    case body
    case data
    case caption
    case micro

    fileprivate var font: Font {
        switch self {
        case .display:
            ForgeFont.font(size: 23, relativeTo: .title)
        case .title:
            ForgeFont.font(size: 18, relativeTo: .title2)
        case .heading:
            ForgeFont.font(size: 15, relativeTo: .headline)
        case .body:
            ForgeFont.font(size: 14, relativeTo: .body)
        case .data:
            ForgeFont.font(size: 13, relativeTo: .callout)
        case .caption:
            ForgeFont.font(size: 11, relativeTo: .caption)
        case .micro:
            ForgeFont.font(size: 9, relativeTo: .caption2)
        }
    }

    fileprivate var tracking: CGFloat {
        switch self {
        case .display:
            0.8
        case .title, .heading:
            0.5
        case .caption, .micro:
            1.1
        case .body, .data:
            0.2
        }
    }
}

private struct ForgeTextStyleModifier: ViewModifier {
    let style: ForgeTextStyle

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .tracking(style.tracking)
    }
}

extension View {
    func forgeTextStyle(_ style: ForgeTextStyle) -> some View {
        modifier(ForgeTextStyleModifier(style: style))
    }
}
