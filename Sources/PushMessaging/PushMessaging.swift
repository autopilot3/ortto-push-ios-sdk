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

    /// The device token from the OS. Stored on arrival (even if registration fails) so it can be retried.
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

    /// Clears the registration record (keeps the device token) so the next user re-registers.
    func clearRegistration() {
        latestRegistration = nil
    }

    /// A successful registration: the token we registered and when.
    private struct Registration: Codable {
        let token: PushToken
        let date: Date
    }

    /// The last registration Ortto confirmed (written only on success); used to dedup.
    private var latestRegistration: Registration? {
        get { Ortto.shared.preferences.getObject(key: "latestRegistration", type: Registration.self) }
        set { Ortto.shared.preferences.setObject(object: newValue as Registration?, key: "latestRegistration") }
    }

    /// Registers the token unless it's already registered. Safe to call repeatedly.
    func sendPushRegistration(_ token: PushToken) {
        // Dedup on token, not session: contact switches clear this via clearIdentity.
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
