<!--
  - SPDX-FileCopyrightText: 2022 Nextcloud GmbH and Nextcloud contributors
  - SPDX-License-Identifier: GPL-3.0-or-later
-->
# NextcloudKit V 2
<img src="image.png" alt="Demo of the Nextcloud iOS files app" width="200" height="200">

[![REUSE status](https://api.reuse.software/badge/github.com/nextcloud/NextcloudKit)](https://api.reuse.software/info/github.com/nextcloud/NextcloudKit)

## Installation

### Carthage

[Carthage](https://github.com/Carthage/Carthage) is a decentralized dependency manager that builds your dependencies and provides you with binary frameworks.

To integrate **NextcloudKit** into your Xcode project using Carthage, specify it in your `Cartfile`:

```
github "nextcloud/NextcloudKit" "main"
```

Run `carthage update` to build the framework and drag the built `NextcloudKit.framework` into your Xcode project.

### Swift Package Manager

[Swift Package Manager](https://swift.org/package-manager/) is a tool for automating the distribution of Swift code and is integrated into the `swift` compiler. 

Once you have your Swift package set up, adding NextcloudKit as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/Nextcloud/NextcloudKit.git", .upToNextMajor(from: "2.0.0"))
]
```

### Manual

To add **NextcloudKit** to your app without Carthage, clone this repo and place it somewhere in your project folder. 
Then, add `NextcloudKit.xcodeproj` to your project, select your app target and add the NextcloudKit framework as an embedded binary under `General` and as a target dependency under `Build Phases`.

## Testing

### Unit tests:

Since most functions in NextcloudKit involve a server call, you can mock the Alamofire session request. For that we use [Mocker](https://github.com/WeTransfer/Mocker).

### Integration tests:
To run integration tests, you need a docker instance of a Nextcloud test server. [This](https://github.com/szaimen/nextcloud-easy-test) is a good start.

1. In `TestConstants.swift` you must specify your instance credentials. App Token is automatically generated.

```
public class TestConstants {
    static let timeoutLong: Double = 400
    static let server = "http://localhost:8080"
    static let username = "admin"
    static let password = "admin"
    static let account = "\(username) \(server)"
}
```

2. Run the integration tests. 

## Contribution Guidelines & License

[GPLv3](LICENSE.txt) with [Apple app store exception](COPYING.iOS).

Nextcloud doesn't require a CLA (Contributor License Agreement). The copyright belongs to all the individual contributors. Therefore we recommend that every contributor adds following line to the header of a file, if they changed it substantially:

```
@copyright Copyright (c) <year>, <your name> (<your email address>)
```

Please read the [Code of Conduct](https://nextcloud.com/code-of-conduct/). This document offers some guidance to ensure Nextcloud participants can cooperate effectively in a positive and inspiring atmosphere, and to explain how together we can strengthen and support each other.

More information how to contribute: [https://nextcloud.com/contribute/](https://nextcloud.com/contribute/)
