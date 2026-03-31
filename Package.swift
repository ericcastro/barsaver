// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "barsaver",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "6.0.1")
    ],
    targets: [
        .executableTarget(
            name: "barsaver",
            dependencies: ["Yams"]
        ),
        .testTarget(
            name: "barsaverTests",
            dependencies: ["barsaver"]
        ),
    ]
)
