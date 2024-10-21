// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ChatPlugins",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "ChatPlugins",
            targets: ["TerminalChatPlugin", "ShortcutChatPlugin"]
        ),
    ],
    dependencies: [
        .package(path: "../Tool"),
    ],
    targets: [
        .target(
            name: "TerminalChatPlugin",
            dependencies: [
                .product(name: "Chat", package: "Tool"),
                .product(name: "Terminal", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
            ]
        ),
        .target(
            name: "ShortcutChatPlugin",
            dependencies: [
                .product(name: "Chat", package: "Tool"),
                .product(name: "Terminal", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
            ]
        ),
    ]
)

