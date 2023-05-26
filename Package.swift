// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NextcloudKit",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v10),
        .tvOS(.v10),
        .watchOS(.v3)
    ],
    products: [
        .library(
            name: "NextcloudKit",
            targets: ["NextcloudKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/WeTransfer/Mocker.git", .upToNextMajor(from: "2.3.0")),
        .package(url: "https://github.com/Alamofire/Alamofire", .upToNextMajor(from: "5.4.1")),
        .package(url: "https://github.com/SwiftyJSON/SwiftyJSON", .upToNextMajor(from: "5.0.0")),
        .package(url: "https://github.com/yahoojapan/SwiftyXMLParser", .upToNextMajor(from: "5.3.0")),
    ],
    targets: [
        .target(
            name: "NextcloudKit",
            dependencies: ["Alamofire","SwiftyJSON","SwiftyXMLParser","Mocker"]),
        .testTarget(
            name: "NextcloudKitUnitTests",
            dependencies: ["NextcloudKit"],
            resources: [
                .process("Resources")
            ]),
        .testTarget(
            name: "NextcloudKitIntegrationTests",
            dependencies: ["NextcloudKit"])
    ]
)
