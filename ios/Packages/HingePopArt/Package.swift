// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HingePopArt",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "HingePopArt", targets: ["HingePopArt"]),
        .executable(name: "render-assets", targets: ["render-assets"]),
    ],
    targets: [
        .target(name: "HingePopArt"),
        .executableTarget(name: "render-assets", dependencies: ["HingePopArt"]),
        .testTarget(name: "HingePopArtTests", dependencies: ["HingePopArt"]),
    ]
)
