// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "trackpad-tweaks",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "CMultitouch"),
        .executableTarget(
            name: "TrackpadTweaks",
            dependencies: ["CMultitouch"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/System/Library/PrivateFrameworks",
                    "-framework", "MultitouchSupport",
                ])
            ]
        ),
    ]
)
