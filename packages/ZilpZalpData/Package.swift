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
        // .copy, not .process: Fixtures/valid stays a directory inside
        // Bundle.module, so the tests look the manifests up under the same
        // path the licence gate is run on.
        .testTarget(
            name: "ZilpZalpDataTests",
            dependencies: ["ZilpZalpData"],
            resources: [.copy("Fixtures")],
        ),
    ],
    swiftLanguageModes: [.v6],
)
