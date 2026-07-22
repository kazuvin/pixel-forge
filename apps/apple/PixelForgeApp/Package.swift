// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PixelForgeApp",
    defaultLocalization: "ja",
    platforms: [
        .macOS(.v14),
    ],
    dependencies: [
        .package(path: "../../../packages/PixelCoreKit"),
    ],
    targets: [
        .executableTarget(
            name: "PixelForgeApp",
            dependencies: ["PixelCoreKit"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "PixelForgeAppTests",
            dependencies: ["PixelForgeApp"]
        ),
    ]
)
