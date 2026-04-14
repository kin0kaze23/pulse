// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PulseCore", targets: ["PulseCore"]),
    ],
    targets: [
        // PulseCore: Pure Swift cleanup engine. No AppKit, SwiftUI, ObservableObject, or @Published.
        .target(
            name: "PulseCore",
            path: "Sources/PulseCore"
        ),
        .testTarget(
            name: "PulseCoreTests",
            dependencies: ["PulseCore"],
            path: "Tests/PulseCoreTests"
        ),
        // Pulse: Existing app target (depends on PulseCore)
        .executableTarget(
            name: "Pulse",
            dependencies: ["PulseCore"],
            path: "MemoryMonitor/Sources"
        ),
        .testTarget(
            name: "PulseTests",
            dependencies: ["Pulse"],
            path: "Tests",
            exclude: ["PulseCoreTests"]
        ),
    ]
)
