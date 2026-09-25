// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RulesEngine",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "RulesEngine", targets: ["RulesEngine"])],
    targets: [
        .target(name: "RulesEngine"),
        .testTarget(name: "RulesEngineTests", dependencies: ["RulesEngine"], resources: [.copy("Fixtures")]),
    ]
)
