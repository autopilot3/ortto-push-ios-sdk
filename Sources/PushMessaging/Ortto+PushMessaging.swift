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
     Update push token (async version that returns result)
     */
    func dispatchPushRequest() async throws -> PushRegistrationResponse? {
        guard let token = PushMessaging.shared.token else {
            Ortto.log().info("Ortto+PushMessaging@dispatchPushRequest.cancel")
            return nil
        }

        return try await self.apiManager.sendPushPermission(sessionID: self.userStorage.session, token: token, permission: true)
    }

    // Backward compatible version
    func dispatchPushRequest(completion: ((Result<PushRegistrationResponse?, Error>) -> Void)? = nil) {
        guard PushMessaging.shared.token != nil else {
            Ortto.log().info("Ortto+PushMessaging@dispatchPushRequest.cancel")
            completion?(.success(nil))
            return
        }

        Task {
            do {
                let result = try await dispatchPushRequest()
                DispatchQueue.main.async {
                    completion?(.success(result))
                }
            } catch {
                Ortto.log().error("PushMessaging@dispatchPushRequest.error \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion?(.failure(error))
                }
            }
        }
    }
}
