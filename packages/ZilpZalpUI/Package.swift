// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ZilpZalpUI",
    // Only iOS ships. macOS is listed so that `swift test` runs straight on
    // the host without a simulator — the fast path for logic tests.
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "ZilpZalpUI", targets: ["ZilpZalpUI"]),
    ],
    targets: [
        .target(name: "ZilpZalpUI", resources: [.process("Resources")]),
        .testTarget(name: "ZilpZalpUITests", dependencies: ["ZilpZalpUI"]),
    ],
    swiftLanguageModes: [.v6],
)
