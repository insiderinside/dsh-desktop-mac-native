// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DSHDesktop",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DSHDesktop", targets: ["DSHDesktop"]),
        .executable(name: "DSHDesktopCheck", targets: ["DSHDesktopCheck"]),
        .library(name: "DSHDesktopCore", targets: ["DSHDesktopCore"]),
        .library(name: "DSHDesktopUI", targets: ["DSHDesktopUI"])
    ],
    targets: [
        .target(
            name: "DSHDesktopCore",
            dependencies: [],
            path: "Sources/DSHDesktop/Core"
        ),
        .target(
            name: "DSHDesktopUI",
            dependencies: ["DSHDesktopCore"],
            path: "Sources/DSHDesktop/UI"
        ),
        .executableTarget(
            name: "DSHDesktop",
            dependencies: ["DSHDesktopCore", "DSHDesktopUI"],
            path: "Sources/DSHDesktop/App"
        ),
        .executableTarget(
            name: "DSHDesktopCheck",
            dependencies: ["DSHDesktopCore"],
            path: "Sources/DSHDesktop/Check"
        )
    ]
)
