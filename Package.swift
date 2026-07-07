// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Dicta",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Dicta",
            path: "Sources/Dicta",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
