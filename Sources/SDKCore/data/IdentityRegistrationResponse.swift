//
//  IdentityRegistrationResponse.swift
//
//
//  Created by Mitch Flindell on 11/10/2023.
//

import Foundation

public struct IdentityRegistrationResponse: Codable {
    let sessionID: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
    }
}
