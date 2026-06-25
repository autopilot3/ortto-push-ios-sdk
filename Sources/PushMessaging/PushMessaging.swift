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

    /// The current device token from the OS. Stored the moment it arrives — even if the
    /// registration below fails — so it can be retried later without the app re-supplying it.
    public var token: PushToken? {
        get {
            Ortto.shared.preferences.getObject(key: "token", type: PushToken.self)
        }
        set {
            guard let newToken = newValue else {
                Ortto.shared.preferences.setObject(object: nil as PushToken?, key: "token")
                latestRegistration = nil
                Ortto.log().info("PushMessaging@token forgotten")
                return
            }
            Ortto.shared.preferences.setObject(object: newToken, key: "token")
            sendPushRegistration(newToken)
        }
    }

    /// A successful registration: the token we registered and when.
    private struct Registration: Codable {
        let token: PushToken
        let date: Date
    }

    /// The latest registration Ortto confirmed. Written only on success, and compared against
    /// an incoming token to decide whether a new registration is actually needed.
    private var latestRegistration: Registration? {
        get { Ortto.shared.preferences.getObject(key: "latestRegistration", type: Registration.self) }
        set { Ortto.shared.preferences.setObject(object: newValue as Registration?, key: "latestRegistration") }
    }

    /// Registers the token with Ortto, unless it's already the registered token. Safe to call as
    /// often as you like — `dispatchPushRequest()` runs this every time — it only hits the network
    /// for a token Ortto hasn't confirmed yet, including retrying after an earlier attempt failed.
    func sendPushRegistration(_ token: PushToken) {
        if let latest = latestRegistration, latest.token == token {
            Ortto.log().info("PushMessaging@registration skip; token already registered \(latest.date)")
            return
        }

        registerDeviceToken(sessionID: Ortto.shared.userStorage.session, token: token) { (response: PushRegistrationResponse?) in
            guard let response else {
                Ortto.log().info("PushMessaging@registration failed; token kept for retry")
                return
            }
            self.latestRegistration = Registration(token: token, date: Date())
            Ortto.shared.setSessionID(response.sessionId)
        }
    }

    func registerDeviceToken(sessionID: String?, token: PushToken, completion: @escaping (PushRegistrationResponse?) -> Void) {
        MessagingService.shared.registerDeviceToken(sessionID: sessionID, token: token, completion: completion)
    }
}
