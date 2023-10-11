//
//  File.swift
//  
//
//  Created by Mitch Flindell on 6/10/2023.
//

import Foundation

public struct PushRegistrationResponse: Codable {
    let sessionID: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
    }
}
