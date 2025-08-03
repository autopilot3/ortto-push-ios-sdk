//
//  PushMessaging.swift
//
//
//  Created by Mitch Flindell on 18/11/2022.
//

import Alamofire
import Foundation
import OrttoSDKCore

#if canImport(UserNotifications) && canImport(UIKit)
    import UIKit
    import UserNotifications
#endif

struct DecodableType: Decodable {
    let session_id: String
}

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
                Ortto.log().info("PushMessaging@token.set session_id not changed")
                return
            }

            registerDeviceToken(
                sessionID: Ortto.shared.userStorage.session,
                token: newToken
            ) { (response: PushRegistrationResponse?) in
                Ortto.shared.preferences.setObject(object: newToken, key: "token")

                if let returnedSessionID = response?.sessionId {
                    Ortto.log().info("PushMessaging@token.set push API returned session: \(returnedSessionID), keeping current session: \(Ortto.shared.userStorage.session ?? "nil")")

                    Ortto.shared.setSessionID(returnedSessionID)
                } else {
                    Ortto.log().info("PushMessaging@token.set res returned no session_id")
                    return
                }
            }
        }
    }

    func registerDeviceToken(sessionID: String?, token: PushToken, completion: @escaping (PushRegistrationResponse?) -> Void) {
        MessagingService.shared.registerDeviceToken(sessionID: sessionID, token: token, completion: completion)
    }
}
