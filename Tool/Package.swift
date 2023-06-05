// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tool",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "Terminal", targets: ["Terminal"]),
        .library(name: "LangChain", targets: ["LangChain", "PythonHelper"]),
        .library(name: "Preferences", targets: ["Preferences", "Configs"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pvieito/PythonKit.git", branch: "master"),
    ],
    targets: [
        // MARK: - Helpers

        .target(name: "Configs"),

        .target(name: "Preferences", dependencies: ["Configs"]),

        .target(name: "Terminal"),

        // MARK: - Services

        .target(
            name: "LangChain",
            dependencies: [
                "PythonHelper",
                .product(name: "PythonKit", package: "PythonKit"),
            ]
        ),

        .target(
            name: "PythonHelper",
            dependencies: [
                .product(name: "PythonKit", package: "PythonKit"),
            ]
        ),

        // MARK: - Tests

        .testTarget(
            name: "LangChainTests",
            dependencies: ["LangChain"]
        ),
    ]
)

