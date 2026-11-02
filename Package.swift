// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Quietly",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Quietly", targets: ["Quietly"])
    ],
    targets: [
        .executableTarget(
            name: "Quietly",
            path: "Sources/Quietly",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "QuietlyTests",
            dependencies: ["Quietly"],
            path: "Tests/QuietlyTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
