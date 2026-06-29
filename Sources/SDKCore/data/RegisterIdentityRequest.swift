//
//  RegisterIdentityRequest.swift
//  Typed descriptor for the push-mobile-session endpoint.
//
//  Created on 25/5/2026.
//

import Foundation

/// Registers the current user identity with Ortto and returns a session ID.
/// Endpoint: POST `/-/events/push-mobile-session`
struct RegisterIdentityRequest: OrttoAPISessionRequest, SendsDeviceContext {
    typealias Response = IdentityRegistrationResponse

    let user: UserIdentifier
    let appKey: String
    let shouldSkipNonExistingContacts: Bool
    // Not a constructor argument — the send middleware sets this (OrttoAPISessionRequest).
    var sessionID: String? = nil

    init(user: UserIdentifier, appKey: String, shouldSkipNonExistingContacts: Bool) {
        self.user = user
        self.appKey = appKey
        self.shouldSkipNonExistingContacts = shouldSkipNonExistingContacts
    }

    var method: HTTPMethod { .post }
    var endpoint: String { "/-/events/push-mobile-session" }
    var isRetryable: Bool { true }

    func persistedSession(from response: IdentityRegistrationResponse) -> String? {
        response.sessionID
    }

    func persistedUser(from _: IdentityRegistrationResponse) -> UserIdentifier? {
        user
    }

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
