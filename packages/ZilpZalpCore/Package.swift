// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "ZilpZalpCore",
    // Ausgeliefert wird nur iOS. macOS steht mit dabei, damit `swift test`
    // ohne Simulator direkt auf dem Host läuft — der schnelle Weg für
    // Logik-Tests.
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
