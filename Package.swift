// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ARIMenu",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ARIMenu",
            path: "Sources/ARIMenu"
        )
    ]
)
