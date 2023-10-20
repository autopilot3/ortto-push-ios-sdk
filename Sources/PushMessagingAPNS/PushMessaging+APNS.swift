//
//  PushMessaging+APNS.swift
//
//
//  Created by Mitch Flindell on 21/11/2022.
//

import Foundation
import OrttoPushMessaging

#if canImport(UserNotifications)
    import UserNotifications
#endif

public typealias PushMessaging = OrttoPushMessaging.PushMessaging

extension PushMessaging: PushMessagingAPNSInterface {
    public func registerDeviceToken(apnsToken: Data) {
        PushMessagingAPNS.shared.registerDeviceToken(apnsToken: apnsToken)
    }

    func application(_ application: Any, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushMessagingAPNS.shared.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    #if canImport(UserNotifications)
        public func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) -> Bool {
            return PushMessagingAPNS.shared.didReceive(request, withContentHandler: contentHandler)
        }

        public func serviceExtensionTimeWillExpire() {
            PushMessagingAPNS.shared.serviceExtensionTimeWillExpire()
        }
    #endif
}
