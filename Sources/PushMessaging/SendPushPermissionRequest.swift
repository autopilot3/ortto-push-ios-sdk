//
//  SendPushPermissionRequest.swift
//  Typed descriptor for the push-permission endpoint.
//
//  Created on 25/5/2026.
//

import Foundation
import OrttoSDKCore

/// Registers or clears push notification permission for the current device token.
/// Endpoint: POST `/-/events/push-permission`
struct SendPushPermissionRequest: OrttoAPISessionRequest, SendsDeviceContext {
    typealias Response = PushRegistrationResponse

    let appKey: String
    let token: PushToken
    let permission: Bool
    // Not a constructor argument — the send middleware sets this (OrttoAPISessionRequest).
    var sessionID: String? = nil

    init(appKey: String, token: PushToken, permission: Bool) {
        self.appKey = appKey
        self.token = token
        self.permission = permission
    }

    var method: HTTPMethod { .post }
    var endpoint: String { "/-/events/push-permission" }
    var isRetryable: Bool { true }

    /// Persist the session only on a registration (`permission == true`); a clear must not re-establish what it cleared.
    func persistedSession(from response: PushRegistrationResponse) -> String? {
        permission ? response.sessionId : nil
    }

    func encodeBody(using encoder: JSONEncoder) throws -> Data? {
        try encoder.encode(PushPermissionRequest(
            appKey: appKey,
            permission: permission,
            sessionID: sessionID,
            deviceToken: token.value,
            pushTokenType: token.type
        ))
    }
}
