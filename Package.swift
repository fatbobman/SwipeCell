// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwipeCell",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "SwipeCell",
            targets: ["SwipeCell"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwipeCell",
            dependencies: [],
            swiftSettings: [
                .defaultIsolation(MainActor.self)
            ]
        ),
        .testTarget(
            name: "SwipeCellTests",
            dependencies: ["SwipeCell"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
