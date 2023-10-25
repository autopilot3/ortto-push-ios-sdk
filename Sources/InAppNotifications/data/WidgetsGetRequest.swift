//
//  WidgetsGetRequest.swift
//
//
//  Created by Mitch Flindell on 27/6/2023.
//

import Foundation

struct WidgetsGetRequest: Codable {
    let sessionId: String?
    let contactId: String?
    let emailAddress: String?
    let phoneNumber: String?
    let applicationKey: String
    let talkEnabled: Bool
    let talkToken: String?
    let url: String?
    let ottlk: String

    enum CodingKeys: String, CodingKey {
        case sessionId = "s"
        case contactId = "c"
        case emailAddress = "e"
        case phoneNumber = "p"
        case applicationKey = "h"
        case talkEnabled = "tk"
        case talkToken = "tt"
        case url = "u"
        case ottlk
    }

    init(sessionId: String?, applicationKey: String, contactId: String? = nil, emailAddress: String? = nil) {
        self.sessionId = sessionId
        self.applicationKey = applicationKey
        self.contactId = contactId
        self.emailAddress = emailAddress
        phoneNumber = nil
        talkEnabled = false
        talkToken = nil
        url = nil
        ottlk = ""
    }
}
