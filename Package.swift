// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Droplime",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Droplime"),
        .testTarget(name: "DroplimeTests", dependencies: ["Droplime"]),
    ]
)
