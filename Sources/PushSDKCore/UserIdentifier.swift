//
//  UserIdentifier.swift
//
//
//  Created by Mitch Flindell on 18/11/2022.

import Foundation

public struct UserIdentifier: Codable {
    var contactID: String?
    var email: String?
    var phone: String?
    var externalID: String?
    var firstName: String?
    var lastName: String?
    var acceptsGDPR: Bool = false

    public init(
        contactID: String?,
        email: String?,
        phone: String?,
        externalID: String?,
        firstName: String?,
        lastName: String?,
        acceptsGDPR: Bool = true
    ) {
        self.contactID = contactID
        self.email = email
        self.phone = phone
        self.externalID = externalID
        self.firstName = firstName
        self.lastName = lastName
        self.acceptsGDPR = acceptsGDPR
    }

    enum CodingKeys: String, CodingKey {
        case contactID = "contact_id"
        case email
        case phone
        case externalID = "external_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case acceptsGDPR = "accepts_gdpr"
    }
}
