// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Python",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "Python", targets: ["Python", "PythonResources"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(name: "Python", path: "Python.xcframework"),
        .target(name: "PythonResources")
    ]
)

