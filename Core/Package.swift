// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "Service",
            targets: ["Service", "SuggestionInjector"]
        ),
        .library(
            name: "Client",
            targets: ["CopilotModel", "Client"]
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
        .target(
            name: "Client",
            dependencies: ["CopilotModel", "XPCShared"]
        ),
        .target(
            name: "Service",
            dependencies: ["CopilotModel", "CopilotService", "XPCShared"]
        ),
        .target(
            name: "XPCShared",
            dependencies: ["CopilotModel"]
        ),
        .testTarget(
            name: "ServiceTests",
            dependencies: ["Service", "Client", "CopilotService", "SuggestionInjector", "XPCShared"]
        ),
    ]
)
