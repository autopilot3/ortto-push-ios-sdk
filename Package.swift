// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OrttoSDK",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_14)
    ],
    products: [
        .library(name: "OrttoPushSDKCore", targets: ["OrttoPushSDKCore"]),
        .library(name: "OrttoPushMessagingFCM", targets: ["OrttoPushMessagingFCM"]),
        .library(name: "OrttoPushMessagingAPNS", targets: ["OrttoPushMessagingAPNS"]),
        .library(name: "OrttoCaptureSDK", targets: ["OrttoCaptureSDK"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.6.1")),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", .upToNextMajor(from: "8.0.0")),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.6.0"),
        .package(url: "https://github.com/ashleymills/Reachability.swift", from: "5.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        // Push SDK
        .target(
            name: "OrttoPushSDKCore",
            dependencies: [.product(name: "Alamofire", package: "Alamofire")],
            path: "Sources/PushSDKCore"
        ),
        // FCM
        .target(
            name: "OrttoPushMessagingFCM",
            dependencies: ["OrttoPushSDKCore", .product(name: "FirebaseMessaging", package: "firebase-ios-sdk")],
            path: "Sources/PushMessagingFCM"
        ),
        // PNS
        .target(
            name: "OrttoPushMessagingAPNS",
            dependencies: ["OrttoPushSDKCore"],
            path: "Sources/PushMessagingAPNS"
        ),
        .target(
            name: "OrttoCaptureSDK",
            dependencies: ["OrttoPushSDKCore", "SwiftSoup", .product(name: "Reachability", package: "Reachability.swift")],
            path: "Sources/Capture",
            resources: [
                .process("Resources/WebView")
            ]
        ),
        // Tests
        .testTarget(
            name: "ap3-push-ios-sdkTests",
            dependencies: ["OrttoPushSDKCore"]
        ),
    ]
)

