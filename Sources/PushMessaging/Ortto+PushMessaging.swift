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
     Send push token to Ortto API
     */
    internal func updatePushToken(token: PushToken, force: Bool = false) {
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
