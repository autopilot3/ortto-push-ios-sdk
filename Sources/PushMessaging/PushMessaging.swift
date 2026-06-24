//
//  PushMessaging.swift
//
//
//  Created by Mitch Flindell on 18/11/2022.
//

import Foundation
import OrttoSDKCore

#if canImport(UserNotifications)
    @preconcurrency import UserNotifications
#endif

#if canImport(UIKit)
    import UIKit
#endif

public protocol PushMessagingInterface {
    func registerDeviceToken(_ deviceToken: String)

    #if canImport(UserNotifications)
        @discardableResult
        func didReceive(
            _ request: UNNotificationRequest,
            withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
        ) -> Bool

        func serviceExtensionTimeWillExpire()
    #endif

    #if canImport(UserNotifications) && canImport(UIKit)
        /*
         A push notification was interacted with.
         - returns: If the SDK called the completion handler for you indicating if the SDK took care of the request or not.
         */
        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) -> Bool

        func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) -> PushNotificationPayload?
    #endif
}

public class PushMessaging {

    public static var shared = PushMessaging()

    public var permission: PushPermission {
        get {
            if let value = Ortto.shared.preferences.getString("pushPermission") {
                return PushPermission(rawValue: value)!
            }
            return PushPermission.Automatic
        }
        set {
            Ortto.shared.preferences.setString(newValue.rawValue, key: "pushPermission")

        }
    }

    public var token: PushToken? {
        get {
            Ortto.shared.preferences.getObject(key: "token", type: PushToken.self)
        }
        set {
            guard let newToken = newValue else {
                // If new value is nil, remove the existing token
                Ortto.shared.preferences.setObject(object: nil as PushToken?, key: "token")
                Ortto.log().info("PushMessaging@token.set removing token")
                return
            }

            if let existingToken = Ortto.shared.preferences.getObject(key: "token", type: PushToken.self),
               existingToken == newToken {
                Ortto.log().info("PushMessaging@token.set unchanged token; skipping (call dispatchPushRequest() to force a re-send)")
                return
            }

            sendPushRegistration(newToken)
        }
    }

    /// Sends the token + permission to Ortto. Bypasses the unchanged-token skip in the
    /// setter, so it also re-sends when the session/permission changed after the token
    /// was first cached (e.g. identify completed after the token arrived).
    func sendPushRegistration(_ newToken: PushToken) {
        registerDeviceToken(
            sessionID: Ortto.shared.userStorage.session,
            token: newToken
        ) { (response: PushRegistrationResponse?) in
            guard let sessionID = response?.sessionId else {
                // Send failed — don't cache the token, so the next dispatch retries
                // instead of being skipped by the unchanged-token check.
                Ortto.log().info("PushMessaging@token.set send failed; not caching token (will retry)")
                return
            }

            // Cache only after a successful send.
            Ortto.shared.preferences.setObject(object: newToken, key: "token")
            Ortto.shared.setSessionID(sessionID)
        }
    }

    func registerDeviceToken(sessionID: String?, token: PushToken, completion: @escaping (PushRegistrationResponse?) -> Void) {
        MessagingService.shared.registerDeviceToken(sessionID: sessionID, token: token, completion: completion)
    }
}
