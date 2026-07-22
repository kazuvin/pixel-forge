import SwiftUI

enum ForgeIconName {
    case sliders
    case addPhoto
    case camera
    case files
    case minus
    case plus
    case render
    case export
    case savePhoto
    case photo
    case pixelGrid
    case selected
    case unselected
    case trash
    case edit
    case duplicate
    case close
    case lock
    case link
    case restore

    fileprivate var pixels: [CGRect] {
        switch self {
        case .sliders:
            [
                pixel(2, 3, 3, 1), pixel(7, 3, 7, 1), pixel(5, 2, 2, 3),
                pixel(2, 8, 8, 1), pixel(12, 8, 2, 1), pixel(10, 7, 2, 3),
                pixel(2, 13, 5, 1), pixel(9, 13, 5, 1), pixel(7, 12, 2, 3),
            ]
        case .addPhoto:
            [
                pixel(1, 4, 10, 1), pixel(1, 5, 1, 8), pixel(11, 7, 1, 6), pixel(1, 12, 11, 1),
                pixel(3, 6, 2, 2),
                pixel(3, 10, 1, 1), pixel(4, 9, 1, 1), pixel(5, 8, 1, 1),
                pixel(6, 9, 1, 1), pixel(7, 10, 1, 1), pixel(8, 9, 1, 1),
                pixel(9, 10, 1, 1), pixel(10, 11, 1, 1),
                pixel(13, 1, 1, 5), pixel(11, 3, 5, 1),
            ]
        case .camera:
            [
                pixel(2, 5, 12, 1), pixel(2, 6, 1, 7), pixel(13, 6, 1, 7),
                pixel(2, 12, 12, 1), pixel(5, 3, 6, 2),
                pixel(6, 7, 4, 1), pixel(5, 8, 1, 3), pixel(10, 8, 1, 3),
                pixel(6, 11, 4, 1), pixel(7, 8, 2, 3),
            ]
        case .files:
            [
                pixel(3, 2, 6, 1), pixel(3, 3, 1, 11), pixel(3, 13, 10, 1),
                pixel(12, 6, 1, 8), pixel(9, 3, 1, 4), pixel(10, 6, 3, 1),
                pixel(6, 8, 5, 1), pixel(6, 10, 5, 1),
            ]
        case .minus:
            [pixel(3, 7, 10, 2)]
        case .plus:
            [pixel(7, 3, 2, 10), pixel(3, 7, 10, 2)]
        case .render:
            [
                pixel(2, 2, 2, 2), pixel(7, 2, 2, 2), pixel(12, 2, 2, 2),
                pixel(2, 7, 2, 2), pixel(7, 7, 2, 2), pixel(12, 7, 2, 2),
                pixel(2, 12, 2, 2), pixel(7, 12, 2, 2), pixel(12, 12, 2, 2),
            ]
        case .export:
            [
                pixel(7, 1, 2, 7),
                pixel(4, 5, 1, 1), pixel(5, 6, 1, 1), pixel(6, 7, 1, 1),
                pixel(9, 7, 1, 1), pixel(10, 6, 1, 1), pixel(11, 5, 1, 1),
                pixel(2, 10, 1, 4), pixel(3, 13, 10, 1), pixel(13, 10, 1, 4),
            ]
        case .savePhoto:
            [
                pixel(2, 7, 12, 1), pixel(2, 8, 1, 6), pixel(13, 8, 1, 6),
                pixel(2, 13, 12, 1), pixel(4, 9, 2, 2),
                pixel(6, 12, 1, 1), pixel(7, 11, 1, 1), pixel(8, 10, 1, 1),
                pixel(9, 11, 1, 1), pixel(10, 10, 1, 1), pixel(11, 11, 1, 1),
                pixel(7, 1, 2, 6), pixel(5, 4, 1, 1), pixel(6, 5, 1, 1),
                pixel(9, 5, 1, 1), pixel(10, 4, 1, 1),
            ]
        case .photo:
            [
                pixel(2, 3, 12, 1), pixel(2, 4, 1, 10), pixel(13, 4, 1, 10), pixel(2, 13, 12, 1),
                pixel(4, 5, 2, 2),
                pixel(4, 11, 1, 1), pixel(5, 10, 1, 1), pixel(6, 9, 1, 1),
                pixel(7, 10, 1, 1), pixel(8, 11, 1, 1), pixel(9, 10, 1, 1),
                pixel(10, 9, 1, 1), pixel(11, 8, 1, 1), pixel(12, 9, 1, 1),
            ]
        case .pixelGrid:
            [
                pixel(2, 2, 4, 4), pixel(7, 2, 3, 4), pixel(11, 2, 3, 4),
                pixel(2, 7, 3, 3), pixel(6, 7, 4, 3), pixel(11, 7, 3, 3),
                pixel(2, 11, 4, 3), pixel(7, 11, 3, 3), pixel(11, 11, 3, 3),
            ]
        case .selected:
            [
                pixel(2, 2, 12, 1), pixel(2, 13, 12, 1), pixel(2, 3, 1, 10), pixel(13, 3, 1, 10),
                pixel(4, 8, 1, 1), pixel(5, 9, 1, 1), pixel(6, 10, 1, 1),
                pixel(7, 11, 1, 1), pixel(8, 10, 1, 1), pixel(9, 9, 1, 1),
                pixel(10, 8, 1, 1), pixel(11, 7, 1, 1),
            ]
        case .unselected:
            [
                pixel(2, 2, 12, 1), pixel(2, 13, 12, 1), pixel(2, 3, 1, 10), pixel(13, 3, 1, 10),
            ]
        case .trash:
            [
                pixel(4, 4, 8, 1), pixel(6, 2, 4, 2), pixel(5, 6, 1, 8),
                pixel(8, 6, 1, 8), pixel(11, 6, 1, 8), pixel(5, 14, 7, 1),
            ]
        case .edit:
            [
                pixel(3, 12, 2, 2), pixel(5, 10, 2, 2), pixel(7, 8, 2, 2),
                pixel(9, 6, 2, 2), pixel(11, 4, 2, 2), pixel(12, 3, 2, 2),
                pixel(3, 14, 5, 1),
            ]
        case .duplicate:
            [
                pixel(5, 2, 8, 1), pixel(5, 3, 1, 9), pixel(12, 3, 1, 9),
                pixel(5, 11, 8, 1), pixel(3, 5, 1, 9), pixel(4, 13, 7, 1),
            ]
        case .close:
            [
                pixel(3, 3, 2, 2), pixel(5, 5, 2, 2), pixel(7, 7, 2, 2),
                pixel(9, 9, 2, 2), pixel(11, 11, 2, 2), pixel(11, 3, 2, 2),
                pixel(9, 5, 2, 2), pixel(5, 9, 2, 2), pixel(3, 11, 2, 2),
            ]
        case .lock:
            [
                pixel(5, 2, 6, 1), pixel(4, 3, 2, 5), pixel(10, 3, 2, 5),
                pixel(3, 7, 10, 8), pixel(7, 9, 2, 4),
            ]
        case .link:
            [
                pixel(3, 8, 2, 4), pixel(4, 6, 5, 2), pixel(4, 12, 5, 2),
                pixel(11, 4, 2, 4), pixel(7, 2, 5, 2), pixel(7, 8, 5, 2),
                pixel(6, 7, 4, 2),
            ]
        case .restore:
            [
                pixel(3, 4, 8, 2), pixel(2, 5, 2, 5), pixel(4, 9, 2, 3),
                pixel(6, 11, 6, 2), pixel(11, 7, 2, 5), pixel(2, 3, 4, 1),
            ]
        }
    }
}

enum ForgeIconColorRole {
    case ink
    case muted
    case accent
    case accentInk
}

struct ForgeIcon: View {
    @Environment(\.forgePalette) private var palette
    let name: ForgeIconName
    var size: CGFloat = 16
    var colorRole: ForgeIconColorRole = .ink

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, canvasSize in
            let scale = max(1, floor(min(canvasSize.width, canvasSize.height) / 16))
            let origin = CGPoint(
                x: (canvasSize.width - (16 * scale)) / 2,
                y: (canvasSize.height - (16 * scale)) / 2
            )
            var path = Path()
            for pixel in name.pixels {
                path.addRect(
                    CGRect(
                        x: origin.x + (pixel.minX * scale),
                        y: origin.y + (pixel.minY * scale),
                        width: pixel.width * scale,
                        height: pixel.height * scale
                    )
                )
            }
            context.fill(path, with: .color(color))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var color: Color {
        switch colorRole {
        case .ink:
            palette.ink
        case .muted:
            palette.muted
        case .accent:
            palette.accent
        case .accentInk:
            palette.accentInk
        }
    }
}

private func pixel(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
    CGRect(x: x, y: y, width: width, height: height)
}
