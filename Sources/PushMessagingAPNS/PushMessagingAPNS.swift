//
//  PushMessagingAPNS.swift
//
//
//  Created by Mitch Flindell on 18/11/2022.
//

import Foundation
import OrttoSDKCore
import OrttoPushMessaging

#if canImport(UserNotifications)
    import UserNotifications
#endif

protocol PushMessagingAPNSInterface {
    /**
     Accept a push notification registration token and pass it along to the messaging service
     */
    func registerDeviceToken(apnsToken: Data)

    /**
     Handle a push notification registration error
     */
    func application(_ application: Any, didFailToRegisterForRemoteNotificationsWithError error: Error)

    #if canImport(UserNotifications)
        /**
            Handle an incoming push notification from the background APNS service
         */
        @discardableResult
        func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) -> Bool

        /**
         Handle and incoming service expiration time and close out the processing of any notifications
         */
        func serviceExtensionTimeWillExpire()
    #endif
}

public class PushMessagingAPNS: PushMessagingAPNSInterface {
    static let shared = PushMessagingAPNS()

    var messaging: MessagingService {
        MessagingService.shared
    }

    public func registerDeviceToken(apnsToken: Data) {
        let token = apnsToken.map { String(format: "%02.2hhx", $0) }.joined()
        messaging.registerDeviceToken(token: token, tokenType: "apn")
    }

    public func application(_: Any, didFailToRegisterForRemoteNotificationsWithError _: Error) {}

    public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) -> Bool {
        return messaging.didReceive(request, withContentHandler: contentHandler)
    }

    public func serviceExtensionTimeWillExpire() {
        messaging.serviceExtensionTimeWillExpire()
    }
}
