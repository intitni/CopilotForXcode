// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "Service",
            targets: [
                "Service",
                "SuggestionInjector",
                "FileChangeChecker",
                "LaunchAgentManager",
                "UpdateChecker",
                "Logger",
            ]
        ),
        .library(
            name: "Client",
            targets: [
                "CopilotModel",
                "Client",
                "XPCShared",
                "LaunchAgentManager",
                "Logger",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/LanguageClient", from: "0.3.1"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
        .package(url: "https://github.com/raspu/Highlightr", from: "2.1.0"),
        .package(url: "https://github.com/JohnSundell/Splash", from: "0.1.0"),
        .package(url: "https://github.com/nmdias/FeedKit", from: "9.1.2"),
    ],
    targets: [
        .target(name: "CGEventObserver"),
        .target(
            name: "CopilotService",
            dependencies: ["LanguageClient", "CopilotModel", "XPCShared"]
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
            dependencies: ["CopilotModel", "XPCShared", "Logger"]
        ),
        .target(
            name: "Service",
            dependencies: [
                "CopilotModel",
                "CopilotService",
                "XPCShared",
                "CGEventObserver",
                "DisplayLink",
                "ActiveApplicationMonitor",
                "AXNotificationStream",
                "Environment",
                "SuggestionWidget",
                "AXExtension",
                "Logger",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .target(
            name: "XPCShared",
            dependencies: ["CopilotModel"]
        ),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "CopilotService",
                "SuggestionInjector",
                "XPCShared",
                "Environment",
            ]
        ),
        .target(name: "FileChangeChecker"),
        .target(name: "LaunchAgentManager"),
        .target(name: "DisplayLink"),
        .target(name: "ActiveApplicationMonitor"),
        .target(name: "AXNotificationStream"),
        .target(
            name: "Environment",
            dependencies: ["ActiveApplicationMonitor", "CopilotService", "AXExtension"]
        ),
        .target(
            name: "SuggestionWidget",
            dependencies: [
                "ActiveApplicationMonitor",
                "AXNotificationStream",
                "Environment",
                "Highlightr",
                "Splash",
            ]
        ),
        .target(
            name: "UpdateChecker",
            dependencies: ["Logger", .product(name: "FeedKit", package: "FeedKit")]
        ),
        .target(name: "AXExtension"),
        .target(name: "Logger"),
        .target(
            name: "OpenAIService",
            dependencies: [.product(name: "AsyncAlgorithms", package: "swift-async-algorithms")]
        ),
        .testTarget(
            name: "OpenAIServiceTests",
            dependencies: ["OpenAIService"]
        ),
    ]
)
