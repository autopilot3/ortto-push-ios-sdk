//
//  Ortto+PushMessaging.swift
//
//
//  Created by Mitch Flindell on 6/10/2023.
//

import Foundation
import OrttoSDKCore

public extension Ortto {

    /**
     Set explicit permission to send push notifications
     */
    internal func setPushPermission(_ permission: PushPermission) {
        PushMessaging.shared.permission = permission
    }

    internal func getToken() -> String? {
        PushMessaging.shared.token?.value
    }

    func clearIdentity(_ completion: @escaping (PushRegistrationResponse?) -> Void) {
        MessagingService.shared.clearIdentity { response in
            Ortto.shared.clearData()
            completion(response)
        }
    }

    /**
     Store the device token and register it with Ortto unless it's already registered.
     */
    internal func updatePushToken(token: PushToken) {
        PushMessaging.shared.token = token
    }

    /**
     A new device token arrived from the OS — store it and register.
     */
    internal func dispatchPushRequest(_ token: PushToken) {
        updatePushToken(token: token)
    }

    /**
     Register the stored token with Ortto. Skips the network call when that token is already
     registered, and retries when an earlier attempt failed — so it's safe to call often.
     */
    func dispatchPushRequest() {
        guard let token = PushMessaging.shared.token else {
            Ortto.log().info("Ortto+PushMessaging@dispatchPushRequest.cancel")
            return
        }
        PushMessaging.shared.sendPushRegistration(token)
    }
}
