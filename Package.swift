// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Loom",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Loom", targets: ["Loom"])
    ],
    targets: [
        .executableTarget(
            name: "Loom",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
