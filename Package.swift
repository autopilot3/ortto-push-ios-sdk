// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OrttoSDK",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_14),
    ],
    products: [
        .library(name: "OrttoSDKCore", targets: ["OrttoSDKCore"]),
        .library(name: "OrttoPushMessagingFCM", targets: ["OrttoPushMessagingFCM"]),
        .library(name: "OrttoPushMessagingAPNS", targets: ["OrttoPushMessagingAPNS"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.6.1")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "8.0.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        // Push SDK
        .target(
            name: "OrttoSDKCore",
            dependencies: [.product(name: "Alamofire", package: "Alamofire")],
            path: "Sources/SDKCore"
        ),
        // Tests
        .testTarget(
            name: "OrttoSDKTests",
            dependencies: ["OrttoSDKCore"],
            path: "Tests/OrttoSDKTests"
        ),
        // FCM
        .target(
            name: "OrttoPushMessagingFCM",
            dependencies: ["OrttoSDKCore", .product(name: "FirebaseMessaging", package: "firebase-ios-sdk")],
            path: "Sources/PushMessagingFCM"
        ),
        // PNS
        .target(
            name: "OrttoPushMessagingAPNS",
            dependencies: ["OrttoSDKCore"],
            path: "Sources/PushMessagingAPNS"
        ),
    ]
)
