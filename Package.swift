// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Writo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Writo",
            targets: ["Writo"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Writo",
            dependencies: [],
            path: "Sources/Writo"
        ),
        .testTarget(
            name: "WritoTests",
            dependencies: ["Writo"],
            path: "Tests/WritoTests"
        )
    ]
)
