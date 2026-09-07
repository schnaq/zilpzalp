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
        // .copy, not .process: the pack directory keeps its shape inside
        // Bundle.module, so `photos/amsel.png` from the manifest resolves
        // against the bundle exactly as it does against data/packs.
        .target(name: "ZilpZalpData", resources: [.copy("Resources/Packs")]),
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
