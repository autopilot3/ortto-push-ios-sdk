//
//  PushMessaging+FCM.swift
//
//  Created by Mitch Flindell on 18/11/2022.
//  Extension for OrttoSDKCore.PushMessaging class that Ortto customers
//  will use to receive events from firebase messaging
//

import Foundation
import OrttoSDKCore
#if canImport(UserNotifications)
    import UserNotifications
#endif

public typealias PushMessaging = OrttoSDKCore.PushMessaging

// This will expose FCM pushMessaging class
// This class extends SDK PushMessaging to interact with firebase properly
extension PushMessaging: PushMessagingFCMInterface {
    public func registerDeviceToken(fcmToken: String?) {
        PushMessagingFCM.shared.registerDeviceToken(fcmToken: fcmToken)
    }

    public func messaging(_ messaging: Any, didReceiveRegistrationToken fcmToken: String?) {
        PushMessagingFCM.shared.messaging(messaging, didReceiveRegistrationToken: fcmToken)
    }

    public func application(_ application: Any, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushMessagingFCM.shared.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    #if canImport(UserNotifications)
        @discardableResult
        public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) -> Bool {
            return PushMessagingFCM.shared.didReceive(request, withContentHandler: contentHandler)
        }

        public func serviceExtensionTimeWillExpire() {
            PushMessagingFCM.shared.serviceExtensionTimeWillExpire()
        }
    #endif
}
