// swift-tools-version: 6.0
import PackageDescription

// Path to the Rust release library
let rustLibPath = "../omnireader-core/target/release"

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
        // System library for the Rust FFI bindings
        .systemLibrary(
            name: "omnireader_coreFFI",
            path: "OmniReaderApp/Generated"
        ),
        
        // Main application target
        .executableTarget(
            name: "OmniReaderApp",
            dependencies: ["omnireader_coreFFI"],
            path: "OmniReaderApp",
            exclude: ["Generated/omnireader_coreFFI.h", "Generated/module.modulemap"],
            sources: [
                "OmniReaderApp.swift", 
                "RustBridge.swift", 
                "Models/Book.swift", 
                "ViewModels/LibraryViewModel.swift", 
                "Views/ContentView.swift",
                "Views/LibraryView.swift", 
                "Views/ReaderView.swift",
                "Generated/omnireader_core.swift"
            ],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .unsafeFlags(["-L\(rustLibPath)", "-lomnireader_core"])
            ]
        )
    ]
)
