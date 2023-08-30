//
//  PushMessagingFCM.swift
//  demo-app
//
//  Created by Mitch Flindell on 18/11/2022.
//

import Foundation
import OrttoPushSDKCore

#if canImport(UserNotifications)
    import UserNotifications
#endif

/**
 * Interface that is exposed via the PushMessagingFCM SDK
 */
public protocol PushMessagingFCMInterface {
    /**
     Accept a firebase push registration token and pass it along to the messaging service
     */
    func registerDeviceToken(fcmToken: String?)

    /**
     Accept a firebase push registration token directly from the appdelegate
     */
    func messaging(_ messaging: Any, didReceiveRegistrationToken fcmToken: String?)

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

public class PushMessagingFCM: PushMessagingFCMInterface {
    static let shared = PushMessagingFCM()

    var messaging: MessagingService {
        MessagingService.shared
    }

    public func registerDeviceToken(fcmToken: String?) {
        guard let deviceToken = fcmToken else {
            Ortto.log().info("PushMessagingFCM.registerDeviceToken.fail token=nil")
            return
        }

        messaging.registerDeviceToken(token: deviceToken, tokenType: "fcm")
    }

    public func messaging(_: Any, didReceiveRegistrationToken fcmToken: String?) {
        guard let deviceToken = fcmToken else {
            return
        }

        registerDeviceToken(fcmToken: deviceToken)
    }

    public func application(_: Any, didFailToRegisterForRemoteNotificationsWithError _: Error) {}

    #if canImport(UserNotifications)
        @discardableResult
        public func didReceive(
            _ request: UNNotificationRequest,
            withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
        ) -> Bool {
            return messaging.didReceive(request, withContentHandler: contentHandler)
        }

        public func serviceExtensionTimeWillExpire() {
            messaging.serviceExtensionTimeWillExpire()
        }
    #endif
}
