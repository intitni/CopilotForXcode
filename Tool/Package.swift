// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tool",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "Terminal", targets: ["Terminal"]),
        .library(name: "LangChain", targets: ["LangChain", "PythonHelper", "BingSearchService"]),
        .library(name: "Preferences", targets: ["Preferences", "Configs"]),
        .library(name: "Logger", targets: ["Logger"]),
        .library(name: "OpenAIService", targets: ["OpenAIService"]),
    ],
    dependencies: [
        .package(path: "../Python"),
        .package(url: "https://github.com/pvieito/PythonKit.git", branch: "master"),
        .package(url: "https://github.com/alfianlosari/GPTEncoder", from: "1.0.4"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/ChimeHQ/JSONRPC", from: "0.6.0"),
    ],
    targets: [
        // MARK: - Helpers

        .target(name: "Configs"),

        .target(name: "Preferences", dependencies: ["Configs"]),

        .target(name: "Terminal"),

        .target(name: "Logger"),

        // MARK: - Services

        .target(
            name: "LangChain",
            dependencies: [
                "PythonHelper",
                "OpenAIService",
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "PythonKit", package: "PythonKit"),
            ]
        ),

        .target(name: "BingSearchService"),

        .target(
            name: "PythonHelper",
            dependencies: [
                .product(name: "Python", package: "Python"),
                .product(name: "PythonKit", package: "PythonKit"),
            ]
        ),

        // MARK: - OpenAI

        .target(
            name: "OpenAIService",
            dependencies: [
                "GPTEncoder",
                "Logger",
                "Preferences",
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .testTarget(
            name: "OpenAIServiceTests",
            dependencies: ["OpenAIService"]
        ),

        // MARK: - Tests

        .testTarget(
            name: "LangChainTests",
            dependencies: ["LangChain"]
        ),
    ]
)

