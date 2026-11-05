// swift-tools-version: 6.0
import PackageDescription

// HingePopCore: the whole game as pure logic. No UIKit, SwiftUI or SpriteKit here, so every rule is
// unit-tested and bots can play thousands of levels in seconds (`swift run hp-balance`).
let package = Package(
  name: "HingePopCore",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [.library(name: "HingePopCore", targets: ["HingePopCore"])],
  targets: [
    .target(name: "HingePopCore", swiftSettings: [.swiftLanguageMode(.v5)]),
    .executableTarget(name: "hp-balance", dependencies: ["HingePopCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
    .testTarget(name: "HingePopCoreTests", dependencies: ["HingePopCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
  ]
)
