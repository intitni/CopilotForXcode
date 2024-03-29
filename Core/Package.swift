// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// MARK: - Pro

extension [Target.Dependency] {
    func pro(_ targetNames: [String]) -> [Target.Dependency] {
        if isProIncluded {
            // include the pro package
            return self + targetNames.map { Target.Dependency.product(name: $0, package: "Pro") }
        }
        return self
    }
}

extension [Package.Dependency] {
    var pro: [Package.Dependency] {
        if isProIncluded {
            // include the pro package
            return self + [.package(path: "../Pro/Pro")]
        }
        return self
    }
}

let isProIncluded: Bool = {
    func isProIncluded(file: StaticString = #file) -> Bool {
        let filePath = "\(file)"
        let fileURL = URL(fileURLWithPath: filePath)
        let rootURL = fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let confURL = rootURL.appendingPathComponent("PLUS")
        if !FileManager.default.fileExists(atPath: confURL.path) {
            return false
        }
        do {
            if let content = try String(
                data: Data(contentsOf: confURL),
                encoding: .utf8
            ) {
                if content.hasPrefix("YES") {
                    return true
                }
            }
            return false
        } catch {
            return false
        }
    }

    return isProIncluded()
}()

// MARK: - Package

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
            ]
        ),
        .library(
            name: "Client",
            targets: [
                "Client",
            ]
        ),
        .library(
            name: "HostApp",
            targets: [
                "HostApp",
                "Client",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
    ],
    dependencies: [
        .package(path: "../Tool"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.1.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "0.5.1"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "0.55.0"
        ),
        // quick hack to support custom UserDefaults
        // https://github.com/sindresorhus/KeyboardShortcuts
        .package(url: "https://github.com/intitni/KeyboardShortcuts", branch: "main"),
    ].pro,
    targets: [
        // MARK: - Main

        .target(
            name: "Client",
            dependencies: [
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
            ]
        ),
        .target(
            name: "Service",
            dependencies: [
                "SuggestionWidget",
                "SuggestionService",
                "ChatService",
                "PromptToCodeService",
                "ServiceUpdateMigration",
                "ChatGPTChatTab",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "Workspace", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ].pro([
                "ProService",
            ])
        ),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "SuggestionInjector",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
            ]
        ),

        // MARK: - Host App

        .target(
            name: "HostApp",
            dependencies: [
                "Client",
                "LaunchAgentManager",
                "PlusFeatureFlag",
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "Toast", package: "Tool"),
                .product(name: "SharedUIComponents", package: "Tool"),
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ].pro([
                "ProHostApp",
            ])
        ),

        // MARK: - Suggestion Service

        .target(
            name: "SuggestionService",
            dependencies: [
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool")
            ].pro([
                "ProExtension",
            ])
        ),
        .target(
            name: "SuggestionInjector",
            dependencies: [.product(name: "SuggestionModel", package: "Tool")]
        ),
        .testTarget(
            name: "SuggestionInjectorTests",
            dependencies: ["SuggestionInjector"]
        ),

        // MARK: - Prompt To Code

        .target(
            name: "PromptToCodeService",
            dependencies: [
                .product(name: "FocusedCodeFinder", package: "Tool"),
                .product(name: "SuggestionModel", package: "Tool"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ].pro([
                "ProService",
            ])
        ),
        .testTarget(name: "PromptToCodeServiceTests", dependencies: ["PromptToCodeService"]),

        // MARK: - Chat

        .target(
            name: "ChatService",
            dependencies: [
                "ChatPlugin",

                // plugins
                "MathChatPlugin",
                "SearchChatPlugin",
                "ShortcutChatPlugin",

                // context collectors
                "WebChatContextCollector",
                "SystemInfoChatContextCollector",

                .product(name: "ChatContextCollector", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
            ].pro([
                "ProService",
            ])
        ),
        .testTarget(name: "ChatServiceTests", dependencies: ["ChatService"]),
        .target(
            name: "ChatPlugin",
            dependencies: [
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Terminal", package: "Tool"),
            ]
        ),

        .target(
            name: "ChatGPTChatTab",
            dependencies: [
                "ChatService",
                .product(name: "SharedUIComponents", package: "Tool"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Terminal", package: "Tool"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),

        // MARK: - UI

        .target(
            name: "SuggestionWidget",
            dependencies: [
                "PromptToCodeService",
                "ChatGPTChatTab",
                .product(name: "Toast", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "SharedUIComponents", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "CustomAsyncAlgorithms", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(name: "SuggestionWidgetTests", dependencies: ["SuggestionWidget"]),

        // MARK: - Helpers

        .target(name: "FileChangeChecker"),
        .target(name: "LaunchAgentManager"),
        .target(
            name: "UpdateChecker",
            dependencies: [
                "Sparkle",
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
            ]
        ),
        .target(
            name: "ServiceUpdateMigration",
            dependencies: [
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Keychain", package: "Tool"),
            ]
        ),
        .testTarget(
            name: "ServiceUpdateMigrationTests",
            dependencies: [
                "ServiceUpdateMigration",
            ]
        ),
        .target(
            name: "PlusFeatureFlag",
            dependencies: [
            ].pro([
                "LicenseManagement",
            ])
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
                .product(name: "ChatContextCollector", package: "Tool"),
                .product(name: "LangChain", package: "Tool"),
                .product(name: "OpenAIService", package: "Tool"),
                .product(name: "ExternalServices", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
            ],
            path: "Sources/ChatContextCollectors/WebChatContextCollector"
        ),

        .target(
            name: "SystemInfoChatContextCollector",
            dependencies: [
                .product(name: "ChatContextCollector", package: "Tool"),
                .product(name: "OpenAIService", package: "Tool"),
            ],
            path: "Sources/ChatContextCollectors/SystemInfoChatContextCollector"
        ),
    ]
)

