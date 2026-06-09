# ap3-push-ios-sdk

Customer Data, Messaging & Analytics Working Together


# Ortto.com iOS SDK

This package is meant to help you integrate Push Notification channel from the Ortto service in your iOS applications. 

Integration documentation is available at [this link](https://help.ortto.com/developer/latest/developer-guide/push-sdks/ios-sdk.html)

## Installation

Swift Package Manager is the supported installation path for new integrations and future releases.

CocoaPods support is deprecated. Version 1.9.1 is intended to be the final CocoaPods maintenance release, updating Firebase Messaging to the Firebase 12.x line.

This release supports Firebase 12.x. Firebase 11.x and older are no longer supported because Google only maintains the latest Firebase major version: https://firebase.google.com/policies/changes-to-firebase/versioning-and-maintenance

Firebase 13.x will require a future Ortto SDK compatibility update.

Firebase has announced that new Firebase Apple SDK versions will stop being published to CocoaPods after October 2026, and the CocoaPods trunk is expected to become read-only in December 2026.

Firebase 12 requires iOS 15.0 and Xcode 26.2 or later.

 
## Packges

We support both Firebase and APNS messaging routes. 

| Package | Purpose | Description |
| :-- | :---: | :--- |
| OrttoSDKCore | Core SDK | Track User identities  |
| OrttoPushMessaging | Push Notifications | Send Push messages, register push tokens | 
| OrttoPushMessagingFCM | Firebase SDK | Send Push messages via Firebase |
| OrttoPushMessagingAPNS | APNS SDK | Send push messages directly via APNS |


## How to include this library locally 
[Watch this video](https://www.youtube.com/watch?v=cGtEF6vR3QY)

Basically:
- Drag the folder into your app package
- It should show up as a folder with a library icon 
- Go to App -> Build Phases -> Link Binary With Libraries -> + (ADD)
- Select the packages you want to include (OrttoSDKCore) AND (OrttoPushMessagingFCM OR OrttoPushMessagingAPNS)

## 
Register
Ortto.shared.identify()

PushMessaging.shared.registerDevice(token)

// 
