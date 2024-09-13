// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tool",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "XPCShared", targets: ["XPCShared"]),
        .library(name: "Terminal", targets: ["Terminal"]),
        .library(name: "LangChain", targets: ["LangChain"]),
        .library(name: "ExternalServices", targets: ["BingSearchService"]),
        .library(name: "Preferences", targets: ["Preferences", "Configs"]),
        .library(name: "Logger", targets: ["Logger"]),
        .library(name: "OpenAIService", targets: ["OpenAIService"]),
        .library(name: "ChatTab", targets: ["ChatTab"]),
        .library(name: "FileSystem", targets: ["FileSystem"]),
        .library(
            name: "ChatContextCollector",
            targets: ["ChatContextCollector", "ActiveDocumentChatContextCollector"]
        ),
        .library(name: "SuggestionBasic", targets: ["SuggestionBasic", "SuggestionInjector"]),
        .library(name: "PromptToCode", targets: ["PromptToCodeBasic", "PromptToCodeCustomization"]),
        .library(name: "ASTParser", targets: ["ASTParser"]),
        .library(name: "FocusedCodeFinder", targets: ["FocusedCodeFinder"]),
        .library(name: "Toast", targets: ["Toast"]),
        .library(name: "Keychain", targets: ["Keychain"]),
        .library(name: "SharedUIComponents", targets: ["SharedUIComponents"]),
        .library(name: "UserDefaultsObserver", targets: ["UserDefaultsObserver"]),
        .library(name: "Workspace", targets: ["Workspace"]),
        .library(name: "WorkspaceSuggestionService", targets: ["WorkspaceSuggestionService"]),
        .library(
            name: "SuggestionProvider",
            targets: ["SuggestionProvider", "GitHubCopilotService", "CodeiumService"]
        ),
        .library(
            name: "AppMonitoring",
            targets: [
                "XcodeInspector",
                "ActiveApplicationMonitor",
                "AXExtension",
                "AXNotificationStream",
                "AppActivator",
            ]
        ),
        .library(name: "GitIgnoreCheck", targets: ["GitIgnoreCheck"]),
        .library(name: "DebounceFunction", targets: ["DebounceFunction"]),
        .library(name: "AsyncPassthroughSubject", targets: ["AsyncPassthroughSubject"]),
        .library(name: "CustomAsyncAlgorithms", targets: ["CustomAsyncAlgorithms"]),
        .library(name: "CommandHandler", targets: ["CommandHandler"]),
        .library(name: "CodeDiff", targets: ["CodeDiff"]),
    ],
    dependencies: [
        // A fork of https://github.com/aespinilla/Tiktoken to allow loading from local files.
        .package(url: "https://github.com/intitni/Tiktoken", branch: "main"),
        // TODO: Update LanguageClient some day.
        .package(url: "https://github.com/ChimeHQ/LanguageClient", exact: "0.3.1"),
        .package(url: "https://github.com/ChimeHQ/LanguageServerProtocol", exact: "0.8.0"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/ChimeHQ/JSONRPC", exact: "0.6.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/unum-cloud/usearch", from: "0.19.1"),
        .package(url: "https://github.com/intitni/Highlightr", branch: "master"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            exact: "1.10.4"
        ),
        .package(url: "https://github.com/apple/swift-syntax.git", exact: "509.0.2"),
        .package(url: "https://github.com/GottaGetSwifty/CodableWrappers", from: "2.0.7"),
        // A fork of https://github.com/google/generative-ai-swift to support setting base url.
        .package(
            url: "https://github.com/intitni/generative-ai-swift",
            branch: "support-setting-base-url"
        ),
        .package(url: "https://github.com/intitni/CopilotForXcodeKit", from: "0.7.1"),

        // TreeSitter
        .package(url: "https://github.com/intitni/SwiftTreeSitter.git", branch: "main"),
        .package(url: "https://github.com/lukepistrol/tree-sitter-objc", branch: "feature/spm"),
    ],
    targets: [
        // MARK: - Helpers

        .target(name: "XPCShared", dependencies: ["SuggestionBasic", "Logger"]),

        .target(name: "Configs"),

        .target(name: "Preferences", dependencies: ["Configs", "AIModel"]),

        .target(name: "Terminal"),

        .target(name: "Logger"),

        .target(name: "FileSystem"),

        .target(name: "ObjectiveCExceptionHandling"),

        .target(name: "CodeDiff", dependencies: ["SuggestionBasic"]),
        .testTarget(name: "CodeDiffTests", dependencies: ["CodeDiff"]),

        .target(
            name: "CustomAsyncAlgorithms",
            dependencies: [
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),

        .target(
            name: "Keychain",
            dependencies: ["Configs", "Preferences"]
        ),

        .testTarget(
            name: "KeychainTests",
            dependencies: ["Keychain"]
        ),

        .target(
            name: "Toast",
            dependencies: [.product(
                name: "ComposableArchitecture",
                package: "swift-composable-architecture"
            )]
        ),

        .target(name: "DebounceFunction"),

        .target(
            name: "AppActivator",
            dependencies: [
                "XcodeInspector",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),

        .target(name: "ActiveApplicationMonitor"),

        .target(name: "USearchIndex", dependencies: [
            "ObjectiveCExceptionHandling",
            .product(name: "USearch", package: "usearch"),
        ]),

        .target(
            name: "TokenEncoder",
            dependencies: [
                .product(name: "Tiktoken", package: "Tiktoken"),
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift"),
            ],
            resources: [
                .copy("Resources/cl100k_base.tiktoken"),
            ]
        ),
        .testTarget(
            name: "TokenEncoderTests",
            dependencies: ["TokenEncoder"]
        ),

        .target(
            name: "SuggestionBasic",
            dependencies: [
                "LanguageClient",
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "CodableWrappers", package: "CodableWrappers"),
            ]
        ),

        .target(
            name: "SuggestionInjector",
            dependencies: ["SuggestionBasic"]
        ),
        .testTarget(
            name: "SuggestionInjectorTests",
            dependencies: ["SuggestionInjector"]
        ),

        .target(
            name: "AIModel",
            dependencies: [
                .product(name: "CodableWrappers", package: "CodableWrappers"),
            ]
        ),

        .testTarget(
            name: "SuggestionBasicTests",
            dependencies: ["SuggestionBasic"]
        ),

        .target(
            name: "ChatBasic",
            dependencies: [
                "AIModel",
                "Preferences",
                "Keychain",
                .product(name: "CodableWrappers", package: "CodableWrappers"),
            ]
        ),

        .target(
            name: "PromptToCodeBasic",
            dependencies: [
                "SuggestionBasic",
                .product(name: "CodableWrappers", package: "CodableWrappers"),
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                ),
            ]
        ),

        .target(
            name: "PromptToCodeCustomization",
            dependencies: [
                "PromptToCodeBasic",
                "SuggestionBasic",
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                ),
            ]
        ),

        .target(name: "AXExtension"),

        .target(
            name: "AXNotificationStream",
            dependencies: [
                "Preferences",
                "Logger",
            ]
        ),

        .target(
            name: "XcodeInspector",
            dependencies: [
                "AXExtension",
                "SuggestionBasic",
                "AXNotificationStream",
                "Logger",
                "Toast",
                "Preferences",
                "AsyncPassthroughSubject",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),

        .testTarget(name: "XcodeInspectorTests", dependencies: ["XcodeInspector"]),

        .target(name: "UserDefaultsObserver"),

        .target(name: "AsyncPassthroughSubject"),

        .target(
            name: "BuiltinExtension",
            dependencies: [
                "SuggestionBasic",
                "SuggestionProvider",
                "ChatBasic",
                "Workspace",
                "ChatTab",
                "AIModel",
                .product(name: "CopilotForXcodeKit", package: "CopilotForXcodeKit"),
            ]
        ),

        .target(
            name: "SharedUIComponents",
            dependencies: [
                "Highlightr",
                "Preferences",
                "SuggestionBasic",
                "DebounceFunction",
                "CodeDiff",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(name: "SharedUIComponentsTests", dependencies: ["SharedUIComponents"]),

        .target(name: "ASTParser", dependencies: [
            "SuggestionBasic",
            .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
            .product(name: "TreeSitterObjC", package: "tree-sitter-objc"),
        ]),

        .testTarget(name: "ASTParserTests", dependencies: ["ASTParser"]),

        .target(
            name: "Workspace",
            dependencies: [
                "GitIgnoreCheck",
                "UserDefaultsObserver",
                "SuggestionBasic",
                "Logger",
                "Preferences",
                "XcodeInspector",
            ]
        ),

        .target(
            name: "WorkspaceSuggestionService",
            dependencies: [
                "Workspace",
                "SuggestionProvider",
                "XPCShared",
                "BuiltinExtension",
                "SuggestionInjector",
            ]
        ),

        .target(
            name: "FocusedCodeFinder",
            dependencies: [
                "Preferences",
                "ASTParser",
                "SuggestionBasic",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "FocusedCodeFinderTests",
            dependencies: ["FocusedCodeFinder"]
        ),

        .target(
            name: "GitIgnoreCheck",
            dependencies: [
                "Terminal",
                "Preferences",
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                ),
            ]
        ),

        .target(
            name: "CommandHandler",
            dependencies: [
                "XcodeInspector",
                "Preferences",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),

        // MARK: - Services

        .target(
            name: "LangChain",
            dependencies: [
                "OpenAIService",
                "ObjectiveCExceptionHandling",
                "USearchIndex",
                "ChatBasic",
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ]
        ),

        .target(name: "BingSearchService"),

        .target(name: "SuggestionProvider", dependencies: [
            "SuggestionBasic",
            "UserDefaultsObserver",
            "Preferences",
            "Logger",
            .product(name: "CopilotForXcodeKit", package: "CopilotForXcodeKit"),
        ]),

        .testTarget(name: "SuggestionProviderTests", dependencies: ["SuggestionProvider"]),

        .target(
            name: "RAGChatAgent",
            dependencies: [
                "ChatBasic",
                "ChatContextCollector",
                "OpenAIService",
                "Preferences",
            ]
        ),

        // MARK: - GitHub Copilot

        .target(
            name: "GitHubCopilotService",
            dependencies: [
                "LanguageClient",
                "SuggestionBasic",
                "ChatBasic",
                "Logger",
                "Preferences",
                "Terminal",
                "BuiltinExtension",
                "Toast",
                "SuggestionProvider",
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "LanguageServerProtocol", package: "LanguageServerProtocol"),
                .product(name: "CopilotForXcodeKit", package: "CopilotForXcodeKit"),
            ],
            resources: [.copy("Resources/load-self-signed-cert-1.34.0.js")]
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
                "Keychain",
                "SuggestionBasic",
                "Preferences",
                "Terminal",
                "XcodeInspector",
                "BuiltinExtension",
                "ChatTab",
                "SharedUIComponents",
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "CopilotForXcodeKit", package: "CopilotForXcodeKit"),
            ]
        ),

        // MARK: - OpenAI

        .target(
            name: "OpenAIService",
            dependencies: [
                "Logger",
                "Preferences",
                "TokenEncoder",
                "Keychain",
                "BuiltinExtension",
                "ChatBasic",
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift"),
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                ),
            ]
        ),
        .testTarget(
            name: "OpenAIServiceTests",
            dependencies: [
                "OpenAIService",
                "ChatBasic",
                .product(
                    name: "ComposableArchitecture",
                    package: "swift-composable-architecture"
                ),
            ]
        ),

        // MARK: - UI

        .target(
            name: "ChatTab",
            dependencies: [.product(
                name: "ComposableArchitecture",
                package: "swift-composable-architecture"
            )]
        ),

        // MARK: - Chat Context Collector

        .target(
            name: "ChatContextCollector",
            dependencies: [
                "SuggestionBasic",
                "ChatBasic",
                "OpenAIService",
            ]
        ),

        .target(
            name: "ActiveDocumentChatContextCollector",
            dependencies: [
                "ASTParser",
                "ChatContextCollector",
                "OpenAIService",
                "Preferences",
                "FocusedCodeFinder",
                "XcodeInspector",
                "GitIgnoreCheck",
            ],
            path: "Sources/ChatContextCollectors/ActiveDocumentChatContextCollector"
        ),

        .testTarget(
            name: "ActiveDocumentChatContextCollectorTests",
            dependencies: ["ActiveDocumentChatContextCollector"]
        ),

        // MARK: - Tests

        .testTarget(
            name: "LangChainTests",
            dependencies: ["LangChain"]
        ),
    ]
)

