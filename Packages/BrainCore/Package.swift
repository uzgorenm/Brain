// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BrainCore",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "BrainCore", targets: ["BrainCore"]),
        .executable(name: "brain-demo", targets: ["BrainCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/google-ai-edge/LiteRT-LM", branch: "main")
    ],
    targets: [
        .target(
            name: "BrainCore",
            dependencies: [
                .product(name: "LiteRTLM", package: "LiteRT-LM")
            ]
        ),
        .executableTarget(
            name: "BrainCLI",
            dependencies: ["BrainCore"]
        ),
        .testTarget(
            name: "BrainCoreTests",
            dependencies: ["BrainCore"]
        )
    ]
)
