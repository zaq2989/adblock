// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CleanViewVPN",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        // Core functionality library
        .library(
            name: "CleanViewCore",
            targets: ["CleanViewCore"]
        ),
        // VPN Extension library
        .library(
            name: "VPNExtension",
            targets: ["VPNExtension"]
        ),
        // Content Blocker library
        .library(
            name: "ContentBlocker",
            targets: ["ContentBlocker"]
        ),
        // Shared utilities
        .library(
            name: "SharedUtilities",
            targets: ["SharedUtilities"]
        ),
    ],
    dependencies: [
        // Add external dependencies here if needed
        // .package(url: "https://github.com/example/package.git", from: "1.0.0"),
    ],
    targets: [
        // Core app functionality
        .target(
            name: "CleanViewCore",
            dependencies: ["SharedUtilities"],
            path: "CleanViewVPN/CleanView",
            exclude: [
                "Resources",
                "Assets.xcassets"
            ],
            sources: [
                "App",
                "Views",
                "Services",
                "Storage"
            ]
        ),

        // VPN Extension
        .target(
            name: "VPNExtension",
            dependencies: ["SharedUtilities"],
            path: "CleanViewVPN/CleanViewVPN",
            exclude: [
                "Info.plist",
                "CleanViewVPN.entitlements"
            ]
        ),

        // Content Blocker Extension
        .target(
            name: "ContentBlocker",
            dependencies: ["SharedUtilities"],
            path: "CleanViewVPN/CleanViewBlocker",
            exclude: [
                "Info.plist",
                "CleanViewBlocker.entitlements"
            ]
        ),

        // Shared utilities and constants
        .target(
            name: "SharedUtilities",
            path: "CleanViewVPN/Shared"
        ),

        // Test targets
        .testTarget(
            name: "CleanViewCoreTests",
            dependencies: ["CleanViewCore"],
            path: "Tests/CleanViewCoreTests"
        ),

        .testTarget(
            name: "VPNExtensionTests",
            dependencies: ["VPNExtension"],
            path: "Tests/VPNExtensionTests"
        ),

        .testTarget(
            name: "ContentBlockerTests",
            dependencies: ["ContentBlocker"],
            path: "Tests/ContentBlockerTests"
        ),
    ]
)

// MARK: - Build Settings
// Additional build settings can be configured per target if needed
// For example, to add specific compiler flags:
/*
for target in package.targets {
    if target.type == .regular {
        target.swiftSettings = [
            .unsafeFlags(["-enable-testing"]),
        ]
    }
}
*/