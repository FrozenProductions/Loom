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
    dependencies: [
        .package(url: "https://github.com/mrkai77/Luminare", from: "0.2.0")
    ],
    targets: [
        .executableTarget(
            name: "Loom",
            dependencies: [
                .product(name: "Luminare", package: "Luminare")
            ],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
