// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "KITimer",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "KITimer",
            path: "Sources/KITimer",
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
