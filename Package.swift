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
        .iOS(.v14),
        .macOS(.v11),
        .tvOS(.v14),
        .watchOS(.v7),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "NextcloudKit",
            targets: ["NextcloudKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/WeTransfer/Mocker.git", .upToNextMajor(from: "3.0.2")),
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.10.2")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", .upToNextMajor(from: "5.0.2")),
        .package(url: "https://github.com/yahoojapan/SwiftyXMLParser", .upToNextMajor(from: "5.6.0")),
    ],
    targets: [
        .target(
            name: "NextcloudKit",
            dependencies: ["Alamofire", "SwiftyJSON", "SwiftyXMLParser"]),
        .testTarget(
            name: "NextcloudKitUnitTests",
            dependencies: ["NextcloudKit", "Mocker"],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "NextcloudKitIntegrationTests",
            dependencies: ["NextcloudKit", "Mocker"])
    ]
)
