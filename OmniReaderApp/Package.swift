// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OmniReaderApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "OmniReaderApp",
            targets: ["OmniReaderApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "OmniReaderApp",
            path: "OmniReaderApp",
            exclude: ["Generated"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
