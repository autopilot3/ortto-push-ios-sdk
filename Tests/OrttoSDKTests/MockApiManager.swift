//
//  MockApiManager.swift
//
//  Created by Mitchell Flindell on 20/6/2024.
//

import Foundation
@testable import OrttoSDKCore

class MockApiManager: ApiManagerInterface {

    var appKey: String? = "mock-app-key"
    var lastTrackingUrl: URL?
    var shouldSucceed = true

    func sendRegisterIdentity(_ storage: any OrttoSDKCore.UserStorage) async throws -> OrttoSDKCore.IdentityRegistrationResponse? {
        IdentityRegistrationResponse(sessionID: "some-session-id")
    }

    func sendLinkTracking(_ trackingUrl: URL) async throws {
        lastTrackingUrl = trackingUrl
        if !shouldSucceed {
            throw OrttoHTTPError.invalidRequest("MockApiManager: configured to fail")
        }
    }

    func send<R: OrttoAPIRequest>(_ request: R) async throws -> R.Response {
        throw OrttoHTTPError.invalidRequest("MockApiManager.send not implemented for \(R.self)")
    }
}
