// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tool",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "Terminal", targets: ["Terminal"]),
        .library(name: "LangChainService", targets: ["LangChainService"]),
    ],
    dependencies: [],
    targets: [
        // MARK: - Helpers

        .target(name: "Terminal"),

        // MARK: - Services

        .target(
            name: "LangChainService",
            dependencies: []
        ),

        // MARK: - Tests

        .testTarget(
            name: "LangChainServiceTests",
            dependencies: ["LangChainService"]
        ),
    ]
)

