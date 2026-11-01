// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Katib",
    platforms: [
        .macOS("14.2")
    ],
    products: [
        .library(
            name: "KatibKit",
            targets: ["KatibKit"]
        ),
        .executable(
            name: "Katib",
            targets: ["Katib"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.15.5"),
        .package(url: "https://github.com/linrol/CreemLicenseKit.git", from: "1.0.1")
    ],
    targets: [
        .target(
            name: "KatibKit",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                "CreemLicenseKit"
            ],
            path: "Sources/KatibKit",
            linkerSettings: [
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ScreenCaptureKit")
            ]
        ),
        .executableTarget(
            name: "Katib",
            dependencies: [
                "KatibKit"
            ],
            path: "Sources/Katib"
        )
    ]
)
