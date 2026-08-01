// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ZilpZalpData",
    // Only iOS ships. macOS is listed so that `swift test` runs straight on
    // the host without a simulator — the fast path for logic tests.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ZilpZalpData", targets: ["ZilpZalpData"]),
    ],
    targets: [
        .target(name: "ZilpZalpData"),
        .testTarget(name: "ZilpZalpDataTests", dependencies: ["ZilpZalpData"]),
    ],
    swiftLanguageModes: [.v6]
)
