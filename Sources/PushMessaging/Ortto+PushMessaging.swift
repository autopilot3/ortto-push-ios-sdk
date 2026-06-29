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

    /// Clears local identity (session/user/registration) and the push permission on the API; the device token is kept. Runs as ONE serial-lane operation so a concurrent `identify` can't interleave and get wiped; local identity is wiped even if the server call fails (then rethrown).
    @discardableResult
    func clearIdentity() async throws -> PushRegistrationResponse? {
        try await Ortto.shared.requestQueue.enqueue {
            defer {
                Ortto.shared.userStorage.session = nil
                Ortto.shared.userStorage.user = nil
                PushMessaging.shared.clearRegistration()
            }
            return try await MessagingService.shared.clearIdentity()
        }
    }

    func clearIdentity(_ completion: @escaping (PushRegistrationResponse?) -> Void) {
        Task {
            let response = try? await clearIdentity()
            // Deliver on main (like identify) — clears identity only; the token isn't identity.
            DispatchQueue.main.async {
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

    /// Re-registers the stored token (skips if already registered); `nil` when there's no token or it's already registered.
    @discardableResult
    func dispatchPushRequest() async throws -> PushRegistrationResponse? {
        guard let token = PushMessaging.shared.token else {
            Ortto.log().info("Ortto+PushMessaging@dispatchPushRequest.cancel")
            return nil
        }
        return try await PushMessaging.shared.sendPushRegistration(token)
    }
}
