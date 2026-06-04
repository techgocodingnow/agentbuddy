// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AgentBuddy",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "AgentBuddyCore",
            path: "Sources/AgentBuddyCore"
        ),
        .executableTarget(
            name: "agentbuddy",
            dependencies: ["AgentBuddyCore", .product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/App"
        ),
        .testTarget(
            name: "AgentBuddyCoreTests",
            dependencies: ["AgentBuddyCore"],
            path: "Tests/AgentBuddyCoreTests"
        ),
    ]
)
