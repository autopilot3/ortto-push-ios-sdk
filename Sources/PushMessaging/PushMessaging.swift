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

            // Dedup guard. The token is only ever cached after a successful send (see
            // sendPushRegistration), so "already cached" means "already registered" —
            // safe to skip. A failed send leaves the cache empty, so the next attempt
            // falls through here and sends. To re-send a still-current token (e.g. the
            // session changed), use dispatchPushRequest(), which bypasses this guard.
            if let existingToken = Ortto.shared.preferences.getObject(key: "token", type: PushToken.self),
               existingToken == newToken {
                Ortto.log().info("PushMessaging@token.set unchanged token; skipping (call dispatchPushRequest() to force a re-send)")
                return
            }

            sendPushRegistration(newToken)
        }
    }

    /// Sends the token + permission to Ortto and caches the token only on success.
    /// Skips the setter's unchanged-token guard, so it also re-sends a still-current
    /// token when the session/permission changed (e.g. identify completed after the
    /// token arrived).
    func sendPushRegistration(_ newToken: PushToken) {
        registerDeviceToken(
            sessionID: Ortto.shared.userStorage.session,
            token: newToken
        ) { (response: PushRegistrationResponse?) in
            // A nil response means the request failed — the API layer collapses any
            // error to nil (ApiManager.sendPushPermission). Don't cache on failure, so
            // the next attempt isn't skipped by the setter's unchanged-token guard.
            guard let response else {
                Ortto.log().info("PushMessaging@token.set send failed; not caching token (will retry)")
                return
            }

            // Succeeded: cache the token now and adopt the returned session.
            Ortto.shared.preferences.setObject(object: newToken, key: "token")
            Ortto.shared.setSessionID(response.sessionId)
        }
    }

    func registerDeviceToken(sessionID: String?, token: PushToken, completion: @escaping (PushRegistrationResponse?) -> Void) {
        MessagingService.shared.registerDeviceToken(sessionID: sessionID, token: token, completion: completion)
    }
}
