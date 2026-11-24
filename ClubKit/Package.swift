// swift-tools-version: 6.0
import PackageDescription

// Everything without UI: API, models, rules. Builds and tests on Linux (`swift test`).
let package = Package(
    name: "ClubKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ClubKit", targets: ["ClubKit"])],
    targets: [
        .target(name: "ClubKit"),
        .testTarget(name: "ClubKitTests", dependencies: ["ClubKit"]),
    ]
)
