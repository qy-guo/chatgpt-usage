// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "ChatGPTUsageBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "ChatGPTUsageCore", targets: ["ChatGPTUsageCore"]),
        .executable(name: "ChatGPTUsageBar", targets: ["ChatGPTUsageBar"]),
        .executable(name: "ChatGPTUsageCoreCheck", targets: ["ChatGPTUsageCoreCheck"])
    ],
    targets: [
        .target(name: "ChatGPTUsageCore"),
        .executableTarget(
            name: "ChatGPTUsageBar",
            dependencies: ["ChatGPTUsageCore"]
        ),
        .executableTarget(
            name: "ChatGPTUsageCoreCheck",
            dependencies: ["ChatGPTUsageCore"]
        )
    ]
)
