// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Tool",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "Terminal", targets: ["Terminal"]),
        .library(name: "LangChain", targets: ["LangChain"]),
        .library(name: "ExternalServices", targets: ["BingSearchService"]),
        .library(name: "Preferences", targets: ["Preferences", "Configs"]),
        .library(name: "Logger", targets: ["Logger"]),
        .library(name: "OpenAIService", targets: ["OpenAIService"]),
        .library(name: "ChatTab", targets: ["ChatTab"]),
        .library(name: "Environment", targets: ["Environment"]),
        .library(name: "SuggestionModel", targets: ["SuggestionModel"]),
        .library(name: "ASTParser", targets: ["ASTParser"]),
        .library(name: "FocusedCodeFinder", targets: ["FocusedCodeFinder"]),
        .library(name: "Toast", targets: ["Toast"]),
        .library(name: "Keychain", targets: ["Keychain"]),
        .library(name: "SharedUIComponents", targets: ["SharedUIComponents"]),
        .library(name: "UserDefaultsObserver", targets: ["UserDefaultsObserver"]),
        .library(name: "CGEventObserver", targets: ["CGEventObserver"]),
        .library(name: "Workspace", targets: ["Workspace"]),
        .library(
            name: "AppMonitoring",
            targets: [
                "XcodeInspector",
                "ActiveApplicationMonitor",
                "AXExtension",
                "AXNotificationStream",
            ]
        ),
    ],
    dependencies: [
        // A fork of https://github.com/aespinilla/Tiktoken to allow loading from local files.
        .package(url: "https://github.com/intitni/Tiktoken", branch: "main"),
        .package(url: "https://github.com/ChimeHQ/LanguageClient", exact: "0.3.1"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "0.1.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/ChimeHQ/JSONRPC", exact: "0.6.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/unum-cloud/usearch", from: "0.19.1"),
        .package(url: "https://github.com/intitni/Highlightr", branch: "bump-highlight-js-version"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "0.55.0"
        ),
        .package(url: "https://github.com/apple/swift-syntax.git", branch: "main"),
        .package(url: "https://github.com/GottaGetSwifty/CodableWrappers", from: "2.0.7"),

        // TreeSitter
        .package(url: "https://github.com/ChimeHQ/SwiftTreeSitter", from: "0.7.1"),
        .package(
            url: "https://github.com/alex-pinkus/tree-sitter-swift",
            branch: "with-generated-files"
        ),
        .package(url: "https://github.com/lukepistrol/tree-sitter-objc", branch: "feature/spm"),
    ],
    targets: [
        // MARK: - Helpers

        .target(name: "Configs"),

        .target(name: "Preferences", dependencies: ["Configs", "AIModel"]),

        .target(name: "Terminal"),

        .target(name: "Logger"),

        .target(name: "ObjectiveCExceptionHandling"),

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

        .target(
            name: "Environment",
            dependencies: [
                "ActiveApplicationMonitor",
                "AXExtension",
                "Preferences",
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
            name: "SuggestionModel",
            dependencies: [
                "LanguageClient",
                .product(name: "Parsing", package: "swift-parsing"),
            ]
        ),

        .target(
            name: "AIModel",
            dependencies: [
                .product(name: "CodableWrappers", package: "CodableWrappers"),
            ]
        ),

        .testTarget(
            name: "SuggestionModelTests",
            dependencies: ["SuggestionModel"]
        ),

        .target(name: "AXExtension"),

        .target(
            name: "AXNotificationStream",
            dependencies: [
                "Logger",
            ]
        ),

        .target(
            name: "XcodeInspector",
            dependencies: [
                "AXExtension",
                "SuggestionModel",
                "Environment",
                "AXNotificationStream",
                "Logger",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),

        .target(name: "UserDefaultsObserver"),

        .target(
            name: "SharedUIComponents",
            dependencies: [
                "Highlightr",
                "Preferences",
            ]
        ),
        .testTarget(name: "SharedUIComponentsTests", dependencies: ["SharedUIComponents"]),

        .target(name: "ASTParser", dependencies: [
            "SuggestionModel",
            .product(name: "SwiftTreeSitter", package: "SwiftTreeSitter"),
            .product(name: "TreeSitterObjC", package: "tree-sitter-objc"),
            .product(name: "TreeSitterSwift", package: "tree-sitter-swift"),
        ]),

        .testTarget(name: "ASTParserTests", dependencies: ["ASTParser"]),

        .target(
            name: "Workspace",
            dependencies: [
                "UserDefaultsObserver",
                "SuggestionModel",
                "Environment",
                "Logger",
                "Preferences",
            ]
        ),

        .target(
            name: "CGEventObserver",
            dependencies: [
                "Logger",
            ]
        ),

        .target(
            name: "FocusedCodeFinder",
            dependencies: [
                "Preferences",
                "ASTParser",
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),

        // MARK: - Services

        .target(
            name: "LangChain",
            dependencies: [
                "OpenAIService",
                "ObjectiveCExceptionHandling",
                "USearchIndex",
                .product(name: "Parsing", package: "swift-parsing"),
                .product(name: "SwiftSoup", package: "SwiftSoup"),
            ]
        ),

        .target(name: "BingSearchService"),

        // MARK: - OpenAI

        .target(
            name: "OpenAIService",
            dependencies: [
                "Logger",
                "Preferences",
                "TokenEncoder",
                "Keychain",
                .product(name: "JSONRPC", package: "JSONRPC"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
            ]
        ),
        .testTarget(
            name: "OpenAIServiceTests",
            dependencies: ["OpenAIService"]
        ),

        // MARK: - UI

        .target(
            name: "ChatTab",
            dependencies: [.product(
                name: "ComposableArchitecture",
                package: "swift-composable-architecture"
            )]
        ),

        // MARK: - Tests

        .testTarget(
            name: "LangChainTests",
            dependencies: ["LangChain"]
        ),
    ]
)

