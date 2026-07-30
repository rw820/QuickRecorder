// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "InterviewAssistant",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "InterviewAssistantCore",
            targets: ["InterviewAssistantCore"]
        ),
        .executable(
            name: "InterviewAssistantApp",
            targets: ["InterviewAssistantApp"]
        ),
        .executable(
            name: "InterviewAssistantTests",
            targets: ["InterviewAssistantTests"]
        )
    ],
    targets: [
        .target(name: "InterviewAssistantCore"),
        .executableTarget(
            name: "InterviewAssistantApp",
            dependencies: ["InterviewAssistantCore"]
        ),
        .executableTarget(
            name: "InterviewAssistantTests",
            dependencies: ["InterviewAssistantCore"],
            path: "Tests/InterviewAssistantTests"
        )
    ]
)
