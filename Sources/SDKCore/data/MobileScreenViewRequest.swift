//
//  MobileScreenViewRequest.swift
//
//
//  Created by iOS SDK Generator
//

import Foundation

struct MobileScreenViewRequest: Codable {
    let appKey: String
    let platform: String = "ios"
    let pushToken: String
    let pushTokenType: String
    let title: String?
    let sessionKey: String?
    let url: String
    let contactId: String?
    let associationEmail: String?
    let associationPhone: String?
    let associationExternalId: String?
    let strategy: String?
    let session: String?
    let firstName: String?
    let lastName: String?
    let acceptGDPR: Bool?
    let skipNonExistingContacts: Bool?

    enum CodingKeys: String, CodingKey {
        case appKey = "appk"
        case platform = "pl"
        case pushToken = "ptk"
        case pushTokenType = "ptkt"
        case title = "title"
        case sessionKey = "sk"
        case url = "u"
        case contactId = "c"
        case associationEmail = "e"
        case associationPhone = "p"
        case associationExternalId = "ei"
        case strategy = "cc"
        case session = "s"
        case firstName = "first"
        case lastName = "last"
        case acceptGDPR = "ag"
        case skipNonExistingContacts = "sne"
    }
}

public struct MobileScreenViewResponse: Codable {
    let known: Bool  // Changed from 'success' to match server response
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case known
        case sessionId = "session_id"
    }

    // Convenience property to maintain backward compatibility
    var success: Bool {
        return known
    }
}
