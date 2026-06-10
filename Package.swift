// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// SPDX-FileCopyrightText: 2022 Nextcloud GmbH and Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//

import PackageDescription

let package = Package(
    name: "NextcloudKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "NextcloudKit",
            targets: ["NextcloudKit"]),
        .library(
            name: "NextcloudKitUI",
            targets: ["NextcloudKitUI"])
    ],
    dependencies: [
        .package(url: "https://github.com/WeTransfer/Mocker.git", .upToNextMajor(from: "3.0.2")),
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.10.2")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", .upToNextMajor(from: "5.0.2")),
        .package(url: "https://github.com/yahoojapan/SwiftyXMLParser", .upToNextMajor(from: "5.6.0")),
        .package(url: "https://github.com/twostraws/CodeScanner.git", .upToNextMajor(from: "2.5.2")),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.63.2"),
    ],
    targets: [
        .target(
            name: "NextcloudKit",
            dependencies: ["Alamofire", "SwiftyJSON", "SwiftyXMLParser"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]),
        .target(
            name: "NextcloudKitUI",
            dependencies: ["NextcloudKit", "CodeScanner"],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ]),
        .testTarget(
            name: "NextcloudKitUnitTests",
            dependencies: ["NextcloudKit", "Mocker"],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "NextcloudKitIntegrationTests",
            dependencies: ["NextcloudKit", "Mocker"]),
        .testTarget(
            name: "NextcloudKitUITests",
            dependencies: ["NextcloudKit", "NextcloudKitUI", "Mocker"]),
    ]
)
