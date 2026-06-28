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
            // Deliver on main (like identify) — clears identity only; the token isn't identity.
            DispatchQueue.main.async {
                Ortto.shared.userStorage.session = nil
                Ortto.shared.userStorage.user = nil
                PushMessaging.shared.clearRegistration()
                completion(response)
            }
        }
    }

    internal func updatePushToken(token: PushToken) {
        PushMessaging.shared.token = token
    }

    internal func dispatchPushRequest(_ token: PushToken) {
        updatePushToken(token: token)
    }

    /// Re-registers the stored token (skips if already registered, retries after a failure).
    func dispatchPushRequest() {
        guard let token = PushMessaging.shared.token else {
            Ortto.log().info("Ortto+PushMessaging@dispatchPushRequest.cancel")
            return
        }
        PushMessaging.shared.sendPushRegistration(token)
    }
}
