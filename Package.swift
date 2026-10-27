// swift-tools-version:5.10
import PackageDescription

// Full concurrency checking in the Swift 5 language mode, so data races show up as warnings.
let strictConcurrency: [SwiftSetting] = [.enableUpcomingFeature("StrictConcurrency")]

let package = Package(
    name: "Droplime",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Droplime", swiftSettings: strictConcurrency),
        .testTarget(name: "DroplimeTests", dependencies: ["Droplime"], swiftSettings: strictConcurrency),
    ]
)
