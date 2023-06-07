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
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
    ],
    dependencies: [
        .package(path: "../Tool"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", from: "0.3.1"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
        .package(url: "https://github.com/raspu/Highlightr", from: "2.1.0"),
        .package(url: "https://github.com/JohnSundell/Splash", branch: "master"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.1.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
        .package(url: "https://github.com/pvieito/PythonKit.git", branch: "master"),
    ],
    targets: [
        // MARK: - Main

        .target(
            name: "Client",
            dependencies: [
                "SuggestionModel",
                "XPCShared",
                "GitHubCopilotService",
                .product(name: "Logger", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
            ]
        ),
        .target(
            name: "Service",
            dependencies: [
                "SuggestionModel",
                "SuggestionService",
                "GitHubCopilotService",
                "XPCShared",
                "CGEventObserver",
                "DisplayLink",
                "ActiveApplicationMonitor",
                "AXNotificationStream",
                "Environment",
                "SuggestionWidget",
                "AXExtension",
                "ChatService",
                .product(name: "Logger", package: "Tool"),
                "PromptToCodeService",
                "ServiceUpdateMigration",
                "UserDefaultsObserver",
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "PythonKit", package: "PythonKit"),
            ]
        ),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "GitHubCopilotService",
                "SuggestionInjector",
                "XPCShared",
                "Environment",
                .product(name: "Preferences", package: "Tool"),
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

        // MARK: - Host App

        .target(
            name: "HostApp",
            dependencies: [
                "Client",
                "GitHubCopilotService",
                "CodeiumService",
                "SuggestionModel",
                "LaunchAgentManager",
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
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
            dependencies: [
                "Environment",
                "GitHubCopilotService",
                "SuggestionModel",
                .product(name: "OpenAIService", package: "Tool"),
            ]
        ),
        .testTarget(name: "PromptToCodeServiceTests", dependencies: ["PromptToCodeService"]),

        // MARK: - Chat

        .target(
            name: "ChatService",
            dependencies: [
                "ChatPlugin",
                "ChatContextCollector",
                "Environment",
                "XcodeInspector",

                // plugins
                "MathChatPlugin",
                "SearchChatPlugin",

                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
            ]
        ),
        .target(
            name: "ChatPlugin",
            dependencies: [
                "Environment",
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Terminal", package: "Tool"),
                .product(name: "PythonKit", package: "PythonKit"),
            ]
        ),
        .target(
            name: "ChatContextCollector",
            dependencies: [
                "Environment",
                "SuggestionModel",
                "XcodeInspector",
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
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
                "XcodeInspector",
                .product(name: "Logger", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ]
        ),
        .testTarget(name: "SuggestionWidgetTests", dependencies: ["SuggestionWidget"]),

        // MARK: - Helpers

        .target(name: "CGEventObserver"),
        .target(name: "FileChangeChecker"),
        .target(name: "LaunchAgentManager"),
        .target(name: "DisplayLink"),
        .target(name: "ActiveApplicationMonitor"),
        .target(name: "AXNotificationStream"),
        .target(
            name: "UpdateChecker",
            dependencies: [
                "Sparkle",
                .product(name: "Logger", package: "Tool"),
            ]
        ),
        .target(name: "AXExtension"),
        .target(
            name: "ServiceUpdateMigration",
            dependencies: [
                "GitHubCopilotService",
                .product(name: "Preferences", package: "Tool"),
            ]
        ),
        .target(name: "UserDefaultsObserver"),
        .target(
            name: "XcodeInspector",
            dependencies: [
                "AXExtension",
                "Environment",
                "AXNotificationStream",
                .product(name: "Logger", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),

        // MARK: - GitHub Copilot

        .target(
            name: "GitHubCopilotService",
            dependencies: [
                "LanguageClient",
                "SuggestionModel",
                "XPCShared",
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Terminal", package: "Tool"),
            ]
        ),
        .testTarget(
            name: "GitHubCopilotServiceTests",
            dependencies: ["GitHubCopilotService"]
        ),

        // MARK: - Codeium

        .target(
            name: "CodeiumService",
            dependencies: [
                "LanguageClient",
                "SuggestionModel",
                "KeychainAccess",
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Terminal", package: "Tool"),
            ]
        ),

        // MARK: - Chat Plugins

        .target(
            name: "MathChatPlugin",
            dependencies: [
                "ChatPlugin",
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "LangChain", package: "Tool"),
                .product(name: "PythonKit", package: "PythonKit"),
            ],
            path: "Sources/ChatPlugins/MathChatPlugin"
        ),

        .target(
            name: "SearchChatPlugin",
            dependencies: [
                "ChatPlugin",
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "LangChain", package: "Tool"),
                .product(name: "PythonKit", package: "PythonKit"),
            ],
            path: "Sources/ChatPlugins/SearchChatPlugin"
        ),
    ]
)

