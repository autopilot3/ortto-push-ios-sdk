// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OrttoSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "OrttoSDKCore", targets: ["OrttoSDKCore"]),
        .library(name: "OrttoPushMessaging", targets: ["OrttoPushMessaging"]),
        .library(name: "OrttoPushMessagingFCM", targets: ["OrttoPushMessagingFCM"]),
        .library(name: "OrttoPushMessagingAPNS", targets: ["OrttoPushMessagingAPNS"]),
        .library(name: "OrttoInAppNotifications", targets: ["OrttoInAppNotifications"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.6.1")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", "10.4.0"..<"13.0.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
    ],
    targets: [
        .target(
            name: "OrttoSDKCore",
            dependencies: [.product(name: "Alamofire", package: "Alamofire"), "SwiftSoup"],
            path: "Sources/SDKCore"
        ),
        .target(
            name: "OrttoInAppNotifications",
            dependencies: ["OrttoSDKCore", .product(name: "Alamofire", package: "Alamofire")],
            path: "Sources/InAppNotifications",
            resources: [
                .process("Resources/WebView.bundle"),
            ]
        ),
        .target(
            name: "OrttoPushMessaging",
            dependencies: ["OrttoSDKCore", .product(name: "Alamofire", package: "Alamofire")],
            path: "Sources/PushMessaging"
        ),
        // Tests
        .testTarget(
            name: "OrttoSDKTests",
            dependencies: ["OrttoSDKCore", "OrttoPushMessaging"],
            path: "Tests/OrttoSDKTests"
        ),
        // FCM
        .target(
            name: "OrttoPushMessagingFCM",
            dependencies: ["OrttoPushMessaging", .product(name: "FirebaseMessaging", package: "firebase-ios-sdk")],
            path: "Sources/PushMessagingFCM"
        ),
        // PNS
        .target(
            name: "OrttoPushMessagingAPNS",
            dependencies: ["OrttoPushMessaging"],
            path: "Sources/PushMessagingAPNS"
        ),
    ]
)
