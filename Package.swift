// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "ConsistencyManager",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v8),
        .tvOS(.v9),
        .watchOS(.v3)
    ],
    products: [
        .library(name: "ConsistencyManager", targets: ["ConsistencyManager"]),
    ],
    targets: [
        .target(name: "ConsistencyManager", path: "ConsistencyManager"),
        .testTarget(
            name: "ConsistencyManagerTests",
            dependencies: ["ConsistencyManager"],
            path: "ConsistencyManagerTests"
        )
    ],
    swiftLanguageVersions: [.v4, .v4_2, .v5]
)
