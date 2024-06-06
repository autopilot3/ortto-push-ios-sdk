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
        MessagingService.shared.clearIdentity(completion: completion)
    }

    /**
     Send push token to Ortto API
     */
    internal func updatePushToken(token: PushToken, force: Bool = false) {
        // Skip registration of the token if it is the same
        if token == PushMessaging.shared.token, !force {
            Ortto.log().info("Ortto@updatePushToken.skip")
            return
        }

        PushMessaging.shared.token = token
    }

    /**
     Update push token
     */
    internal func dispatchPushRequest(_ token: PushToken) {
        updatePushToken(token: token)
    }

    /**
     Update push token
     */
    func dispatchPushRequest() {
        guard let token = PushMessaging.shared.token else {
            Ortto.log().info("Ortto+PushMessaging@dispatchPushRequest.cancel")
            return
        }

        updatePushToken(token: token, force: true)
    }
}
