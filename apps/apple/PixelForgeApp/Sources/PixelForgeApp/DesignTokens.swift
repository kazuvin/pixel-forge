import SwiftUI

enum ForgeDesign {
    enum ColorToken {
        static let canvas = Color(red: 16 / 255, green: 20 / 255, blue: 23 / 255)
        static let panel = Color(red: 24 / 255, green: 33 / 255, blue: 38 / 255)
        static let surface = Color(red: 31 / 255, green: 41 / 255, blue: 46 / 255)
        static let ink = Color(red: 242 / 255, green: 244 / 255, blue: 235 / 255)
        static let muted = Color(red: 143 / 255, green: 161 / 255, blue: 168 / 255)
        static let forge = Color(red: 255 / 255, green: 180 / 255, blue: 91 / 255)
        static let grid = Color(red: 42 / 255, green: 55 / 255, blue: 61 / 255)
        static let danger = Color(red: 244 / 255, green: 124 / 255, blue: 116 / 255)
    }

    enum Spacing {
        static let compact: CGFloat = 8
        static let regular: CGFloat = 16
        static let roomy: CGFloat = 24
    }

    enum Radius {
        static let control: CGFloat = 8
        static let canvas: CGFloat = 12
    }

    static let recipeWidth: CGFloat = 320
}

