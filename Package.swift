// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GalaxyBudsManager",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "GalaxyBudsManager",
            path: "Sources",

            linkerSettings: [
                .linkedFramework("IOBluetooth"),
                .linkedFramework("CoreBluetooth"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(
            name: "GalaxyBudsManagerTests",
            dependencies: ["GalaxyBudsManager"],
            path: "Tests"
        )
    ]
)
