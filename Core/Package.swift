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
                "UserDefaultsObserver",
                "XcodeInspector",
            ]
        ),
        .library(
            name: "Client",
            targets: [
                "SuggestionModel",
                "Client",
                "XPCShared",
                "Preferences",
                "Logger",
            ]
        ),
        .library(
            name: "HostApp",
            targets: [
                "HostApp",
                "SuggestionModel",
                "GitHubCopilotService",
                "Client",
                "XPCShared",
                "Preferences",
                "LaunchAgentManager",
                "Logger",
                "UpdateChecker",
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ChimeHQ/LanguageClient", from: "0.3.1"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
        .package(url: "https://github.com/raspu/Highlightr", from: "2.1.0"),
        .package(url: "https://github.com/JohnSundell/Splash", branch: "master"),
        .package(url: "https://github.com/nmdias/FeedKit", from: "9.1.2"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.1.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/alfianlosari/GPTEncoder", from: "1.0.4"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
    ],
    targets: [
        // MARK: - Main

        .target(
            name: "Client",
            dependencies: [
                "SuggestionModel",
                "Preferences",
                "XPCShared",
                "Logger",
                "GitHubCopilotService",
            ]
        ),
        .target(
            name: "Service",
            dependencies: [
                "SuggestionModel",
                "SuggestionService",
                "GitHubCopilotService",
                "OpenAIService",
                "Preferences",
                "XPCShared",
                "CGEventObserver",
                "DisplayLink",
                "ActiveApplicationMonitor",
                "AXNotificationStream",
                "Environment",
                "SuggestionWidget",
                "AXExtension",
                "Logger",
                "ChatService",
                "PromptToCodeService",
                "ServiceUpdateMigration",
                "UserDefaultsObserver",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "GitHubCopilotService",
                "SuggestionInjector",
                "Preferences",
                "XPCShared",
                "Environment",
            ]
        ),
        .target(
            name: "Environment",
            dependencies: [
                "ActiveApplicationMonitor",
                "AXExtension",
                "SuggestionService",
            ]
        ),
        .target(name: "Preferences", dependencies: ["Configs"]),

        // MARK: - Host App

        .target(
            name: "HostApp",
            dependencies: [
                "Preferences",
                "Client",
                "GitHubCopilotService",
                "CodeiumService",
                "SuggestionModel",
                "LaunchAgentManager",
            ]
        ),

        // MARK: - XPC Related

        .target(
            name: "XPCShared",
            dependencies: ["SuggestionModel"]
        ),

        // MARK: - Suggestion Service

        .target(
            name: "SuggestionModel",
            dependencies: ["LanguageClient"]
        ),
        .testTarget(
            name: "SuggestionModelTests",
            dependencies: ["SuggestionModel"]
        ),
        .target(
            name: "SuggestionInjector",
            dependencies: ["SuggestionModel"]
        ),
        .testTarget(
            name: "SuggestionInjectorTests",
            dependencies: ["SuggestionInjector"]
        ),
        .target(name: "SuggestionService", dependencies: [
            "GitHubCopilotService",
            "CodeiumService",
            "UserDefaultsObserver",
        ]),

        // MARK: - Prompt To Code

        .target(
            name: "PromptToCodeService",
            dependencies: ["OpenAIService", "Environment", "GitHubCopilotService",
                           "SuggestionModel"]
        ),
        .testTarget(name: "PromptToCodeServiceTests", dependencies: ["PromptToCodeService"]),

        // MARK: - Chat

        .target(
            name: "ChatService",
            dependencies: [
                "ChatPlugins",
                "ChatContextCollector",
                "OpenAIService",
                "Environment",
                "XcodeInspector",
                "Preferences",
            ]
        ),
        .target(
            name: "ChatPlugins",
            dependencies: ["OpenAIService", "Environment", "Terminal"]
        ),
        .target(
            name: "ChatContextCollector",
            dependencies: [
                "OpenAIService",
                "Environment",
                "Preferences",
                "SuggestionModel"
            ]
        ),

        // MARK: - UI

        .target(
            name: "SuggestionWidget",
            dependencies: [
                "ActiveApplicationMonitor",
                "AXNotificationStream",
                "Environment",
                "Highlightr",
                "Splash",
                "UserDefaultsObserver",
                "Logger",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ]
        ),
        .testTarget(name: "SuggestionWidgetTests", dependencies: ["SuggestionWidget"]),

        // MARK: - Helpers

        .target(name: "Configs"),
        .target(name: "CGEventObserver"),
        .target(name: "Logger"),
        .target(name: "FileChangeChecker"),
        .target(name: "LaunchAgentManager"),
        .target(name: "DisplayLink"),
        .target(name: "ActiveApplicationMonitor"),
        .target(name: "AXNotificationStream"),
        .target(name: "Terminal"),
        .target(
            name: "UpdateChecker",
            dependencies: [
                "Logger",
                "Sparkle",
                .product(name: "FeedKit", package: "FeedKit"),
            ]
        ),
        .target(name: "AXExtension"),
        .target(
            name: "ServiceUpdateMigration",
            dependencies: ["Preferences", "GitHubCopilotService"]
        ),
        .target(name: "UserDefaultsObserver"),
        .target(
            name: "XcodeInspector",
            dependencies: [
                "AXExtension",
                "Environment",
                "Logger",
                "AXNotificationStream",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),

        // MARK: - GitHub Copilot

        .target(
            name: "GitHubCopilotService",
            dependencies: ["LanguageClient", "SuggestionModel", "XPCShared", "Preferences"]
        ),
        .testTarget(
            name: "GitHubCopilotServiceTests",
            dependencies: ["GitHubCopilotService"]
        ),

        // MARK: - OpenAI

        .target(
            name: "OpenAIService",
            dependencies: [
                "Logger",
                "Preferences",
                "GPTEncoder",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .testTarget(
            name: "OpenAIServiceTests",
            dependencies: ["OpenAIService"]
        ),

        // MARK: - Codeium

        .target(
            name: "CodeiumService",
            dependencies: [
                "LanguageClient",
                "SuggestionModel",
                "Preferences",
                "KeychainAccess",
                "Terminal",
                "Configs",
            ]
        ),
    ]
)

