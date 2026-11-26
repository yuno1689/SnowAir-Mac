// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SnowAirMac",
    platforms: [.macOS(.v14)],
    // 显式锁定 Swift 5 语言模式：Xcode 16 的 Swift 6.1 默认可能因严格并发
    // 把 AppKit 调用（showWindow(nil) 等）判为类型不明，显式 .v5 规避。
    swiftLanguageVersions: [.v5],
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
