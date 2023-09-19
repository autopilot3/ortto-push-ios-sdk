//
//  File.swift
//  
//
//  Created by Mitch Flindell on 17/2/2023.
//

import Foundation

struct PushMobileSessionRequest: Codable {
    
    let appKey: String
    let contactID: String?
    let associationEmail: String?
    let associationPhone: String?
    let associationExternalID: String?
    let sessionID: String?
    let firstName: String?
    let lastName: String?
    let acceptGDPR: Bool
    let platform: String = "ios"
    
    enum CodingKeys: String, CodingKey {
        case appKey = "appk"
        case contactID = "c"
        case associationEmail = "e"
        case associationPhone = "p"
        case associationExternalID = "ei"
        case sessionID = "s"
        case firstName = "first"
        case lastName = "last"
        case acceptGDPR = "ag"
        case platform = "pl"
    }
}

struct PushMobileSessionResponse: Codable {
    let sessionID: String
    
    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
    }
}
