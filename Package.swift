// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Pulse",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Pulse",
            path: "MemoryMonitor/Sources",
            resources: [
                .process("../Resources")
            ]
        ),
        .testTarget(
            name: "PulseTests",
            dependencies: ["Pulse"],
            path: "Tests"
        )
    ]
)
