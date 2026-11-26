// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnowAirMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SnowAirMac", targets: ["SnowAirMac"])
    ],
    targets: [
        // 核心逻辑独立成库，便于 XCTest 覆盖，不依赖 App 生命周期
        .target(name: "SnowAirCore"),
        .executableTarget(
            name: "SnowAirMac",
            dependencies: ["SnowAirCore"],
            exclude: ["Info.plist"]
        ),
        .testTarget(name: "SnowAirCoreTests", dependencies: ["SnowAirCore"])
    ]
)
