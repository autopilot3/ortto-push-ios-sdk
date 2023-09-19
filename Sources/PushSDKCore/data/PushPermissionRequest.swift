//
//  TokenRegistration.swift
//  
//
//  Created by Mitch Flindell on 25/11/2022.
// Registration class adapter for the Ortto API 

import Foundation

struct PushPermissionRequest: Codable {
    let appKey: String
    let permission: Bool
    let platform: String = "ios"
    let sessionID: String?
    let deviceToken: String
    let pushTokenType: String
    
    enum CodingKeys: String, CodingKey {
        case appKey = "appk"
        case permission = "pm"
        case platform = "pl"
        case sessionID = "s"
        case deviceToken = "ptk"
        case pushTokenType = "ptkt"
    }
}

public struct RegistrationResponse: Codable {
    let sessionID: String
    
    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
    }
}
