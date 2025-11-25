// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OverlayWindow",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "OverlayWindow",
            targets: ["OverlayWindow"]
        ),
    ],
    dependencies: [
        .package(path: "../Tool"),
        .package(url: "https://github.com/pointfreeco/swift-perception", from: "1.3.4"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.4.0"),
    ],
    targets: [
        .target(
            name: "OverlayWindow",
            dependencies: [
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Toast", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "Perception", package: "swift-perception"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "OverlayWindowTests",
            dependencies: ["OverlayWindow"]
        ),
    ]
)


