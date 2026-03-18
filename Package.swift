// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Trace",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Trace", targets: ["Trace"])
    ],
    targets: [
        .executableTarget(
            name: "Trace",
            path: "Sources/Trace",
            resources: [
                .process("Resources"),
                .process("trace-logo-dark.png"),
                .process("trace-logo-light.png")
            ]
        ),
        .testTarget(
            name: "TraceTests",
            dependencies: ["Trace"],
            path: "Tests/TraceTests"
        )
    ]
)
