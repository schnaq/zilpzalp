// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ZilpZalpCore",
    // Only iOS ships. macOS is listed so that `swift test` runs straight on
    // the host without a simulator — the fast path for logic tests.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ZilpZalpCore", targets: ["ZilpZalpCore"]),
    ],
    targets: [
        .target(name: "ZilpZalpCore"),
        .testTarget(name: "ZilpZalpCoreTests", dependencies: ["ZilpZalpCore"]),
    ],
    swiftLanguageModes: [.v6]
)
