// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TouchpadExpression",
    platforms: [.macOS(.v14)],
    targets: [
        // C shim: declares the private MultitouchSupport types and loads it via dlopen.
        .target(name: "MTShim"),
        // The menu-bar app. Bundle it with scripts/build-app.sh.
        .executableTarget(name: "TouchpadExpression", dependencies: ["MTShim"]),
        // Original feasibility test (CLI).
        .executableTarget(name: "touchtest", dependencies: ["MTShim"]),
    ]
)
