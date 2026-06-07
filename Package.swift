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
            path: "Sources/App",
            resources: [
                .copy("../../assets/pet-egg.png"),
                .copy("../../assets/pet-egg-crack-small.png"),
                .copy("../../assets/pet-egg-crack-large.png"),
                .copy("../../assets/pet-egg-fragment.png"),
                .copy("../../assets/hatch-chime.wav"),
                .copy("../../assets/super-piglet"),
            ]
        ),
        .testTarget(
            name: "AgentBuddyCoreTests",
            dependencies: ["AgentBuddyCore"],
            path: "Tests/AgentBuddyCoreTests"
        ),
        .testTarget(
            name: "AgentBuddyAppTests",
            dependencies: ["agentbuddy"],
            path: "Tests/AgentBuddyAppTests"
        ),
    ]
)
