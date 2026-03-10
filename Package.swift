// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ImageEditorWheelMath",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ImageEditorWheelMath", targets: ["ImageEditorWheelMath"])
    ],
    targets: [
        .target(
            name: "ImageEditorWheelMath",
            path: "ImageEditor/Shared",
            sources: ["ColorWheelMath.swift"]
        ),
        .testTarget(
            name: "ImageEditorWheelMathTests",
            dependencies: ["ImageEditorWheelMath"],
            path: "ImageEditorTests",
            sources: ["ColorWheelMathTests.swift"]
        )
    ]
)
