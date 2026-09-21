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
        .package(
            url: "https://github.com/aleroot/mlx-swift-lm.git",
            revision: "12ff82f0ea00179cd015efd744c02f993d88ca83"
        ),
        .package(url: "https://github.com/huggingface/swift-huggingface", from: "0.9.0"),
        .package(url: "https://github.com/huggingface/swift-transformers", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "BrainCore",
            dependencies: [
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
                .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
                .product(name: "HuggingFace", package: "swift-huggingface"),
                .product(name: "Tokenizers", package: "swift-transformers")
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
