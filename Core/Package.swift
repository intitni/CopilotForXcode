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
//        .package(url: "https://github.com/pvieito/PythonKit.git", branch: "master"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "0.55.0"
        ),
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
                "PromptToCodeService",
                "ServiceUpdateMigration",
                "UserDefaultsObserver",
                "ChatTab",
                .product(name: "Logger", package: "Tool"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
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
                "SuggestionModel",
                .product(name: "Preferences", package: "Tool"),
            ]
        ),
        .target(
            name: "Environment",
            dependencies: [
                "ActiveApplicationMonitor",
                "AXExtension",
                .product(name: "Preferences", package: "Tool"),
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
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
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
                "ShortcutChatPlugin",

                // context collectors
                "WebChatContextCollector",

                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
            ]
        ),
        .testTarget(name: "ChatServiceTests", dependencies: ["ChatService"]),
        .target(
            name: "ChatPlugin",
            dependencies: [
                "Environment",
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Terminal", package: "Tool"),
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

        .target(
            name: "ChatTab",
            dependencies: [
                "SharedUIComponents",
                "ChatService",
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ]
        ),

        // MARK: - UI

        .target(
            name: "SharedUIComponents",
            dependencies: [
                "Highlightr",
                "Splash",
                .product(name: "Preferences", package: "Tool"),
            ]
        ),
        .testTarget(name: "SharedUIComponentsTests", dependencies: ["SharedUIComponents"]),

        .target(
            name: "SuggestionWidget",
            dependencies: [
                "ChatTab",
                "ActiveApplicationMonitor",
                "AXNotificationStream",
                "Environment",
                "UserDefaultsObserver",
                "XcodeInspector",
                "SharedUIComponents",
                .product(name: "Logger", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
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
                "SuggestionModel",
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
                .product(name: "Logger", package: "Tool"),
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
                "XcodeInspector",
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
            ],
            path: "Sources/ChatPlugins/MathChatPlugin"
        ),

        .target(
            name: "SearchChatPlugin",
            dependencies: [
                "ChatPlugin",
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "LangChain", package: "Tool"),
                .product(name: "ExternalServices", package: "Tool"),
            ],
            path: "Sources/ChatPlugins/SearchChatPlugin"
        ),

        .target(
            name: "ShortcutChatPlugin",
            dependencies: [
                "ChatPlugin",
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "Terminal", package: "Tool"),
            ],
            path: "Sources/ChatPlugins/ShortcutChatPlugin"
        ),

        // MAKR: - Chat Context Collector

        .target(
            name: "WebChatContextCollector",
            dependencies: [
                "ChatContextCollector",
                .product(name: "LangChain", package: "Tool"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "ExternalServices", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
            ],
            path: "Sources/ChatContextCollectors/WebChatContextCollector"
        ),
    ]
)

