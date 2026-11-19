// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CuotaBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "CuotaBar", targets: ["CuotaBar"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "CuotaBar",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "CuotaBar/Sources/CuotaBar",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
