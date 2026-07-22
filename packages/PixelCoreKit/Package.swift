// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PixelCoreKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "PixelCoreKit", targets: ["PixelCoreKit"]),
    ],
    targets: [
        .binaryTarget(
            name: "PixelForgeCoreFFI",
            path: "Artifacts/PixelForgeCoreFFI.xcframework"
        ),
        .target(
            name: "PixelCoreKit",
            dependencies: ["PixelForgeCoreFFI"]
        ),
        .testTarget(
            name: "PixelCoreKitTests",
            dependencies: ["PixelCoreKit"]
        ),
    ]
)
