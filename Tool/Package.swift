// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tool",
    products: [
        .library(
            name: "Tool",
            targets: ["LangChainService"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/pvieito/PythonKit.git", from: "0.3.1"),
    ],
    targets: [
        .target(
            name: "LangChainService",
            dependencies: [
                "PythonKit",
            ]
        ),
        .testTarget(
            name: "LangChainServiceTests",
            dependencies: ["LangChainService"]
        ),
    ]
)

