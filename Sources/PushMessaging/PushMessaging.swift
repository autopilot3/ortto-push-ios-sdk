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
            if let value = Ortto.shared.preferences.getString("pushmessaging:permission") {
                return PushPermission(rawValue: value)!
            }
            return PushPermission.Automatic
        }
        set {
            Ortto.shared.preferences.setString(newValue.rawValue, key: "pushmessaging:permission")
        }
    }

    public var token: PushToken? {
        get {
            Ortto.shared.preferences.getObject(key: "pushmessaging:token", type: PushToken.self)
        }
        set {
            guard let newToken = newValue else {
                return
            }

            Ortto.shared.preferences.setObject(object: newValue, key: "pushmessaging:token")

            registerDeviceToken(
                sessionID: Ortto.shared.userStorage.session,
                deviceToken: newToken.value,
                tokenType: newToken.type
            ) { (response: PushRegistrationResponse?) in
                guard let sessionID = response?.sessionID else {
                    return
                }

                Ortto.shared.setSessionID(sessionID)
            }
        }
    }

    func registerDeviceToken(sessionID: String?, deviceToken: String, tokenType: String = "apn", completion: @escaping (PushRegistrationResponse?) -> Void) {
        guard let endpoint = Ortto.shared.apiEndpoint else {
            return
        }

        var components = URLComponents(string: endpoint)!
        components.path = "/-/events/push-permission"
        components.queryItems = DeviceIdentity.getTrackingQueryItems()

        let tokenRegistration = PushPermissionRequest(
            appKey: Ortto.shared.appKey!,
            permission: getPermission(),
            sessionID: sessionID,
            deviceToken: deviceToken,
            pushTokenType: tokenType
        )

        let headers: HTTPHeaders = [
            .accept("application/json"),
            .userAgent(Alamofire.HTTPHeader.defaultUserAgent.value),
        ]

        #if DEBUG
            debugPrint(tokenRegistration)
        #endif

        AF.request(components.url!, method: .post, parameters: tokenRegistration, encoder: JSONParameterEncoder.default, headers: headers)
            .validate()
            .responseDecodable(of: DecodableType.self) { response in
                guard let data = response.data else { return }
                guard let statusCode = response.response?.statusCode else { return }

                let json = String(data: data, encoding: String.Encoding.utf8) ?? "none"
                Ortto.log().info("PushMessaging@registerDeviceToken status=\(statusCode) body=\(json)")

                switch response.result {
                case .success:
                    let decoder = JSONDecoder()
                    do {
                        let registration = try decoder.decode(PushRegistrationResponse.self, from: data)
                        completion(registration)
                    } catch {
                        Ortto.log().error("PushMessaging@registerDeviceToken.decode.error \(error.localizedDescription)")
                    }
                case let .failure(error):
                    Ortto.log().error("PushMessaging@registerDeviceToken.request.fail \(error.localizedDescription)")
                }
            }
    }

    private func getPermission() -> Bool {
        return permission.isAllowed()
    }
}
