// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MDReader",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "MDReader",
            targets: ["MDReader"]),
    ],
    dependencies: [
        // 如果需要第三方库，可以在这里添加
        // .package(url: "https://github.com/example/repo", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "MDReader",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "MDReaderTests",
            dependencies: ["MDReader"]),
    ]
)
