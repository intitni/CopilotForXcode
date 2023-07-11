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
            ]
        ),
        .library(
            name: "Client",
            targets: [
                "Client",
                "XPCShared",
            ]
        ),
        .library(
            name: "HostApp",
            targets: [
                "HostApp",
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
        // TODO: Update LanguageClient some day.
        .package(url: "https://github.com/ChimeHQ/LanguageClient", exact: "0.3.1"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", exact: "0.8.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
        .package(url: "https://github.com/raspu/Highlightr", from: "2.1.0"),
        .package(url: "https://github.com/JohnSundell/Splash", branch: "master"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.1.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess", from: "4.2.2"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "0.55.0"
        ),
    ].pro,
    targets: [
        // MARK: - Main

        .target(
            name: "Client",
            dependencies: [
                "XPCShared",
                "GitHubCopilotService",
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
            ]
        ),
        .target(
            name: "Service",
            dependencies: [
                "SuggestionService",
                "GitHubCopilotService",
                "XPCShared",
                "CGEventObserver",
                "DisplayLink",
                "SuggestionWidget",
                "ChatService",
                "PromptToCodeService",
                "ServiceUpdateMigration",
                "UserDefaultsObserver",
                "ChatGPTChatTab",
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Environment", package: "Tool"),
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ].pro([
                "ProChatTabs",
            ])
        ),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "GitHubCopilotService",
                "SuggestionInjector",
                "XPCShared",
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "Environment", package: "Tool"),
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
                "LaunchAgentManager",
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),

        // MARK: - XPC Related

        .target(
            name: "XPCShared",
            dependencies: [.product(name: "SuggestionModel", package: "Tool"),]
        ),

        // MARK: - Suggestion Service

        .target(
            name: "SuggestionInjector",
            dependencies: [.product(name: "SuggestionModel", package: "Tool"),]
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
                "GitHubCopilotService",
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "Environment", package: "Tool"),
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

                // plugins
                "MathChatPlugin",
                "SearchChatPlugin",
                "ShortcutChatPlugin",

                // context collectors
                "WebChatContextCollector",

                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Environment", package: "Tool"),
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
            ]
        ),
        .testTarget(name: "ChatServiceTests", dependencies: ["ChatService"]),
        .target(
            name: "ChatPlugin",
            dependencies: [
                .product(name: "Environment", package: "Tool"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Terminal", package: "Tool"),
            ]
        ),
        .target(
            name: "ChatContextCollector",
            dependencies: [
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Environment", package: "Tool"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
            ]
        ),

        .target(
            name: "ChatGPTChatTab",
            dependencies: [
                "SharedUIComponents",
                "ChatService",
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
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
                "ChatGPTChatTab",
                "UserDefaultsObserver",
                "SharedUIComponents",
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Environment", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(name: "SuggestionWidgetTests", dependencies: ["SuggestionWidget"]),

        // MARK: - Helpers

        .target(
            name: "CGEventObserver",
            dependencies: [
                .product(name: "Logger", package: "Tool"),
            ]
        ),
        .target(name: "FileChangeChecker"),
        .target(name: "LaunchAgentManager"),
        .target(name: "DisplayLink"),
        .target(
            name: "UpdateChecker",
            dependencies: [
                "Sparkle",
                .product(name: "Logger", package: "Tool"),
            ]
        ),
        .target(
            name: "ServiceUpdateMigration",
            dependencies: [
                "GitHubCopilotService",
                .product(name: "Preferences", package: "Tool"),
            ]
        ),
        .target(name: "UserDefaultsObserver"),

        // MARK: - GitHub Copilot

        .target(
            name: "GitHubCopilotService",
            dependencies: [
                "LanguageClient",
                "XPCShared",
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Terminal", package: "Tool"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
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
                "KeychainAccess",
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
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

// MARK: - Pro

extension [Target.Dependency] {
    func pro(_ targetNames: [String]) -> [Target.Dependency] {
        if isProIncluded() {
            return self + targetNames.map { Target.Dependency.product(name: $0, package: "Pro") }
        }
        return self
    }
}

extension [Package.Dependency] {
    var pro: [Package.Dependency] {
        if isProIncluded() {
            return self + [.package(path: "../Pro")]
        }
        return self
    }
}

import Foundation

func isProIncluded(file: StaticString = #file) -> Bool {
    let filePath = "\(file)"
    let url = URL(fileURLWithPath: filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Pro/Package.swift")
    return FileManager.default.fileExists(atPath: url.path)
}

