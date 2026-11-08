// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Setal",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SetalCore"),
        .executableTarget(name: "Setal", dependencies: ["SetalCore"]),
        .testTarget(name: "SetalCoreTests", dependencies: ["SetalCore"]),
    ]
)
