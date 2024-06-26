# ap3-push-ios-sdk

Customer Data, Messaging & Analytics Working Together


# Ortto.com iOS SDK

This package is meant to help you integrate Push Notification channel from the Ortto service in your iOS applications. 

Integration documentation is available at [this link](https://help.ortto.com/developer/latest/developer-guide/push-sdks/ios-sdk.html)

 
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
