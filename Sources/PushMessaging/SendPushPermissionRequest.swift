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
struct SendPushPermissionRequest: OrttoAPIRequest, SendsDeviceContext {
    typealias Response = PushRegistrationResponse

    let appKey: String
    let sessionID: String?
    let token: PushToken
    let permission: Bool

    var method: HTTPMethod { .post }
    var endpoint: String { "/-/events/push-permission" }

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
