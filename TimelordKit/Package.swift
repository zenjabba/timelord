// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TimelordKit",
    platforms: [
        .iOS(.v17),
        .watchOS(.v26)
    ],
    products: [
        .library(
            name: "TimelordKit",
            targets: ["TimelordKit"]
        )
    ],
    targets: [
        .target(
            name: "TimelordKit",
            path: "Sources"
        )
    ]
)
