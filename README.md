# NextcloudKit

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
    .package(url: "https://github.com/Nextcloud/NextcloudKit.git", .upToNextMajor(from: "1.0.0"))
]
```

### Manual

To add **NextcloudKit** to your app without Carthage, clone this repo and place it somewhere in your project folder. 
Then, add `NextcloudKit.xcodeproj` to your project, select your app target and add the NextcloudKit framework as an embedded binary under `General` and as a target dependency under `Build Phases`.
