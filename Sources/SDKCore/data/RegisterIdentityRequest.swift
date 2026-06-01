//
//  RegisterIdentityRequest.swift
//  Typed descriptor for the push-mobile-session endpoint.
//
//  Created on 25/5/2026.
//

import Foundation

/// Registers the current user identity with Ortto and returns a session ID.
/// Endpoint: POST `/-/events/push-mobile-session`
struct RegisterIdentityRequest: OrttoAPIRequest, SendsDeviceContext {
    typealias Response = IdentityRegistrationResponse

    let user: UserIdentifier
    let appKey: String
    let sessionID: String?
    let shouldSkipNonExistingContacts: Bool

    var method: HTTPMethod { .post }
    var endpoint: String { "/-/events/push-mobile-session" }

    func encodeBody(using encoder: JSONEncoder) throws -> Data? {
        try encoder.encode(PushMobileSessionRequest(
            appKey: appKey,
            contactID: user.contactID,
            associationEmail: user.email,
            associationPhone: user.phone,
            associationExternalID: user.externalID,
            sessionID: sessionID,
            firstName: user.firstName,
            lastName: user.lastName,
            acceptGDPR: user.acceptsGDPR,
            platform: "ios",
            shouldSkipNonExistingContacts: shouldSkipNonExistingContacts
        ))
    }
}
