# ap3-push-ios-sdk

Customer Data, Messaging & Analytics Working Together


# Ortto.com iOS SDK

This package is meant to help you integrate Push Notification channel from the Ortto service in your iOS applications. 

Integration documentation is available at [this link](https://help.ortto.com/developer/latest/)

 
## Packges

We support both Firebase and APNS messaging routes. 

| Package | Purpose | Description |
| :-- | :---: | :--- |
| OrttoPushSDKCore | Base SDK | Track User identities and register push notification tokens | 
| OrttoPushMessagingFCM | Firebase SDK | Send Push messages via Firebase |
| OrttoPushMessagingAPNS | APNS SDK | Send push messages directly via APNS |


## How to include this library locally 
[Watch this video](https://www.youtube.com/watch?v=cGtEF6vR3QY)

Basically:
- Drag the folder into your app package
- It should show up as a folder with a library icon 
- Go to App -> Build Phases -> Link Binary With Libraries -> + (ADD)
- Select the packages you want to include (OrttoPushSDKCore) AND (OrttoPushMessagingFCM OR OrttoPushMessagingAPNS)

