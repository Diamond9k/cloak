// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Cloak",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Cloak",
            path: "Sources/Cloak"
        )
    ]
)
