// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MiniNotch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MiniNotch",
            path: "Sources/MiniNotch",
            swiftSettings: [
                // Surface every Sendable / isolation issue so they get fixed, not hidden.
                .enableExperimentalFeature("StrictConcurrency")
            ]
        )
    ]
)
