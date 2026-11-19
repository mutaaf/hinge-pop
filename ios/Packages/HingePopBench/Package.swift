// swift-tools-version: 5.9
import PackageDescription

// Headless performance numbers for the parts of a frame that don't need a screen: the rules' step on the
// busiest levels, and how long the art takes to draw. `swift run -c release hp-bench` (see ios/docs/PERF.md).
// Not part of the app; it only depends on the two packages the app uses.
let package = Package(
    name: "HingePopBench",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../HingePopCore"),
        .package(path: "../HingePopArt"),
    ],
    targets: [
        .executableTarget(name: "hp-bench", dependencies: [
            .product(name: "HingePopCore", package: "HingePopCore"),
            .product(name: "HingePopArt", package: "HingePopArt"),
        ]),
    ]
)
