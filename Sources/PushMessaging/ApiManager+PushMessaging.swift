//
//  ApiManager+PushMessaging.swift
//  Push-permission endpoint methods added to ApiManagerInterface via protocol extension.
//  Uses `send<R>` and `appKey` from the protocol so no direct connector access is needed.
//
//  Created by Mitchell Flindell on 21/5/2024.
//

import Foundation
import OrttoSDKCore

extension ApiManagerInterface {

    // MARK: - Callback API (used by MessagingService)

    /// Registers or clears push permission for the current device token.
    /// Calls `completion` on whatever thread the network response arrives on.
    func sendPushPermission(
        sessionID: String?,
        token: PushToken,
        permission: Bool,
        completion: @escaping (PushRegistrationResponse?) -> Void
    ) {
        Task {
            let result = await sendPushPermissionResult(
                sessionID: sessionID,
                token: token,
                permission: permission
            )
            completion(try? result.get())
        }
    }

    // MARK: - Async Result API (used by tests)

    /// Async variant that returns a typed `Result` so tests can assert the specific
    /// failure category rather than only asserting `nil`.
    func sendPushPermissionResult(
        sessionID: String?,
        token: PushToken,
        permission: Bool
    ) async -> Result<PushRegistrationResponse, Error> {
        guard let appKey else {
            let error = OrttoHTTPError.invalidRequest(
                "ApiManager: SDK not initialized. Call Ortto.initialize() before registering push tokens."
            )
            return .failure(error)
        }

        do {
            let request = SendPushPermissionRequest(
                appKey: appKey,
                sessionID: sessionID,
                token: token,
                permission: permission
            )
            let response = try await send(request)
            Ortto.log().info("PushMessaging@sendPushPermission.success session=\(response.sessionId)")
            return .success(response)
        } catch {
            Ortto.log().error("PushMessaging@sendPushPermission.fail \(error.localizedDescription)")
            return .failure(error)
        }
    }
}
