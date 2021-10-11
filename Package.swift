// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "CodeMirror",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v10)
    ],
    products: [
        .library(
            name: "CodeMirror",
            targets: ["CodeMirror"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "CodeMirror",
            dependencies: [],
            resources: [
                .copy("CodeMirrorView.bundle")
            ]
        ),
        .testTarget(
            name: "CodeMirrorTests",
            dependencies: ["CodeMirror"]),
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
