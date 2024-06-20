//
//  MockApiManager.swift
//  
//
//  Created by Mitchell Flindell on 20/6/2024.
//

import Foundation
@testable import OrttoSDKCore

class MockApiManager: ApiManagerInterface {
    func sendRegisterIdentity(_ storage: any OrttoSDKCore.UserStorage) async throws -> OrttoSDKCore.IdentityRegistrationResponse? {
        return IdentityRegistrationResponse(sessionID: "some-session-id")
    }
    
    var lastTrackingUrl: URL?
    var shouldSucceed = true

    func sendLinkTracking(_ trackingUrl: URL) async throws {
        lastTrackingUrl = trackingUrl
        if !shouldSucceed {
            throw APIResponseError.notSuccessful
        }
    }
}
