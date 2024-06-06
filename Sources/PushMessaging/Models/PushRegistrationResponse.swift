//
//  PushRegistrationResponse.swift
//
//
//  Created by Mitch Flindell on 6/10/2023.
//

import Foundation

public struct PushRegistrationResponse: Codable {
    public let sessionId: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
    }
}
