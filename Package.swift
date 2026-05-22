// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "mic-warm",
    platforms: [.macOS(.v13)],
    targets: [
        // Shared session logic used by both targets
        .target(
            name: "MicWarmCore",
            path: "Sources/MicWarmCore",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreAudio"),
            ]
        ),
        // Original CLI daemon — identical behavior to upstream
        .executableTarget(
            name: "mic-warm",
            dependencies: ["MicWarmCore"],
            path: "Sources/MicWarm"
        ),
        // Menu bar app with on/off toggle
        .executableTarget(
            name: "mic-warm-app",
            dependencies: ["MicWarmCore"],
            path: "Sources/MicWarmApp",
            exclude: ["Info.plist", "Resources"],
            linkerSettings: [
                .linkedFramework("AppKit"),
            ]
        ),
    ]
)
