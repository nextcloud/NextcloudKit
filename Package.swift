// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NextcloudKit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v12),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "NextcloudKit",
            targets: ["NextcloudKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/WeTransfer/Mocker.git", .upToNextMajor(from: "2.3.0")),
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.9.1")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/yahoojapan/SwiftyXMLParser", .upToNextMajor(from: "5.3.0")),
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
