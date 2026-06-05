// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VideoTagging",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "VideoTaggingCore", targets: ["VideoTaggingCore"]),
        .executable(name: "VideoTagging", targets: ["VideoTagging"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .target(name: "VideoTaggingCore"),
        .executableTarget(
            name: "VideoTagging",
            dependencies: [
                "VideoTaggingCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .testTarget(
            name: "VideoTaggingCoreTests",
            dependencies: ["VideoTaggingCore"],
            resources: [.copy("Resources/sample.srt")]
        ),
    ]
)
