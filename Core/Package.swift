// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "CopilotService",
            targets: ["CopilotService", "SuggestionInjector"]
        ),
        .library(
            name: "CopilotModel",
            targets: ["CopilotModel"]
        ),
        .library(
            name: "SuggestionInjector",
            targets: ["SuggestionInjector"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/LanguageClient", exact: "0.3.1"),
    ],
    targets: [
        .target(
            name: "CopilotService",
            dependencies: ["LanguageClient", "CopilotModel"]
        ),
        .testTarget(
            name: "CopilotServiceTests",
            dependencies: ["CopilotService"]
        ),
        .target(
            name: "CopilotModel",
            dependencies: ["LanguageClient"]
        ),
        .testTarget(
            name: "CopilotModelTests",
            dependencies: ["CopilotModel"]
        ),
        .target(
            name: "SuggestionInjector",
            dependencies: ["CopilotModel"]
        ),
        .testTarget(
            name: "SuggestionInjectorTests",
            dependencies: ["SuggestionInjector"]
        ),
    ]
)
