// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "AIUsageWidget",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AIUsageCore", targets: ["AIUsageCore"]),
        .executable(name: "AIUsageWidget", targets: ["AIUsageWidget"]),
    ],
    targets: [
        .target(name: "AIUsageCore"),
        .executableTarget(
            name: "AIUsageWidget",
            dependencies: ["AIUsageCore"]
        ),
        .testTarget(
            name: "AIUsageCoreTests",
            dependencies: ["AIUsageCore"]
        ),
    ]
)
