// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "InspireBar",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "InspireBar", targets: ["InspireBar"])],
    targets: [
        .target(name: "InspireBarCore", path: "Sources/CodexBarCore"),
        .executableTarget(
            name: "InspireBar",
            dependencies: ["InspireBarCore"],
            path: "Sources/CodexBar",
            resources: [.copy("Resources/InspireReader")]),
        .testTarget(
            name: "InspireBarTests",
            dependencies: ["InspireBar", "InspireBarCore"],
            path: "Tests/CodexBarTests"),
    ])
