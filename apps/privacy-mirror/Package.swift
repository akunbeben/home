// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "PrivacyMirror",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "PrivacyMirror", targets: ["PrivacyMirror"]),
    ],
    targets: [
        .target(name: "PrivacyMirrorCore"),
        .executableTarget(
            name: "PrivacyMirror",
            dependencies: ["PrivacyMirrorCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("ScreenCaptureKit"),
            ]
        ),
        .testTarget(
            name: "PrivacyMirrorCoreTests",
            dependencies: ["PrivacyMirrorCore"]
        ),
    ]
)
