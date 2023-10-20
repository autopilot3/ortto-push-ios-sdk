//
//  UserIdentifierTest.swift
//
//
//  Created by Mitch Flindell on 31/8/2023.
//

@testable import OrttoSDKCore
import XCTest

final class UserIdentifierTest: XCTestCase {
    func testInit() {
        let user = UserIdentifier(contactID: "1", email: "email@example.com", phone: "1234567890", externalID: "extID", firstName: "John", lastName: "Doe", acceptsGDPR: true)

        XCTAssertEqual(user.contactID, "1")
        XCTAssertEqual(user.email, "email@example.com")
        XCTAssertEqual(user.phone, "1234567890")
        XCTAssertEqual(user.externalID, "extID")
        XCTAssertEqual(user.firstName, "John")
        XCTAssertEqual(user.lastName, "Doe")
        XCTAssertEqual(user.acceptsGDPR, true)
    }

    func testEncoding() throws {
        let user = UserIdentifier(contactID: "1", email: "email@example.com", phone: "1234567890", externalID: "extID", firstName: "John", lastName: "Doe", acceptsGDPR: true)
        let jsonData = try JSONEncoder().encode(user)
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Assert JSON string is as expected
        XCTAssertNotNil(jsonString)
    }

    func testDecoding() throws {
        let jsonString = "{\"contact_id\":\"1\",\"email\":\"email@example.com\",\"phone\":\"1234567890\",\"external_id\":\"extID\",\"first_name\":\"John\",\"last_name\":\"Doe\",\"accepts_gdpr\":true}"
        let jsonData = jsonString.data(using: .utf8)!
        let user = try JSONDecoder().decode(UserIdentifier.self, from: jsonData)

        // Assert properties are decoded correctly
        XCTAssertEqual(user.contactID, "1")
        XCTAssertEqual(user.email, "email@example.com")
        XCTAssertEqual(user.phone, "1234567890")
        XCTAssertEqual(user.externalID, "extID")
        XCTAssertEqual(user.firstName, "John")
        XCTAssertEqual(user.lastName, "Doe")
        XCTAssertEqual(user.acceptsGDPR, true)
    }
}
