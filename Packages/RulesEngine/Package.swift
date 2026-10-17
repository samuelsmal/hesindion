// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RulesEngine",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "RulesEngine", targets: ["RulesEngine"])],
    targets: [
        // Optimised in Debug too: the app is built Debug for the simulator and the device alike
        // (`CONFIG = Debug`), and unoptimised the engine is about five times slower — 18 ms
        // against 3.6 ms a sheet query, which made switching armour on the preparation screen
        // take over a second. The app's own code stays -Onone for the debugger.
        .target(name: "RulesEngine", swiftSettings: [.unsafeFlags(["-O"], .when(configuration: .debug))]),
        .testTarget(name: "RulesEngineTests", dependencies: ["RulesEngine"], resources: [.copy("Fixtures")]),
    ]
)
