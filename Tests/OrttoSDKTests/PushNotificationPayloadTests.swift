//
//  PushNotificationPayloadTests.swift
//
//
//  Created by Mitch Flindell on 20/9/2023.
//

@testable import OrttoPushMessaging
@testable import OrttoSDKCore
import XCTest

final class PushNotificationPayloadTests: XCTestCase {
    func testActionItemEncodingAndDecoding() throws {
        let actionItem = ActionItem(action: "testAction", title: "testTitle", link: "deeplink://some-domain.xyz")
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedData = try encoder.encode(actionItem)
        let decodedActionItem = try decoder.decode(ActionItem.self, from: encodedData)

        // Check object properties
        XCTAssertEqual(actionItem.action, decodedActionItem.action)
        XCTAssertEqual(actionItem.title, decodedActionItem.title)
        XCTAssertEqual(actionItem.link, decodedActionItem.link)

        // Check JSON encoding
        if let jsonString = String(data: encodedData, encoding: .utf8) {
            let expectedJsonString = #"{"link":"deeplink:\/\/some-domain.xyz","title":"testTitle","action":"testAction"}"#
            XCTAssertEqual(jsonString, expectedJsonString)
        } else {
            XCTFail("Failed to convert encoded data to string")
        }
    }

    func testPushNotificationPayloadEncodingAndDecoding() throws {
        let actionItem = ActionItem(action: "testAction", title: "testTitle", link: "deeplink://some-domain.xyz")

        let payload = PushNotificationPayload(
            title: "testTitle",
            body: "testBody",
            image: "testImage",
            link: "testLink",
            actions: [actionItem],
            primaryAction: actionItem,
            eventTrackingUrl: "testTrackingURL",
            notificationID: "testNotificationID"
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let encodedData = try encoder.encode(payload)
        let decodedPayload = try decoder.decode(PushNotificationPayload.self, from: encodedData)

        XCTAssertEqual(payload.title, decodedPayload.title)
        XCTAssertEqual(payload.body, decodedPayload.body)
        XCTAssertEqual(payload.image, decodedPayload.image)
        XCTAssertEqual(payload.link, decodedPayload.link)
        XCTAssertEqual(payload.eventTrackingUrl, decodedPayload.eventTrackingUrl)
        XCTAssertEqual(payload.notificationID, decodedPayload.notificationID)

        // Validate actions
        XCTAssertEqual(payload.actions.count, decodedPayload.actions.count)
        if let firstOriginalAction = payload.actions.first,
           let firstDecodedAction = decodedPayload.actions.first
        {
            XCTAssertEqual(firstOriginalAction.action, firstDecodedAction.action)
            XCTAssertEqual(firstOriginalAction.title, firstDecodedAction.title)
            XCTAssertEqual(firstOriginalAction.link, firstDecodedAction.link)
        }

        // Validate primary action
        XCTAssertEqual(payload.primaryAction?.action, decodedPayload.primaryAction?.action)
        XCTAssertEqual(payload.primaryAction?.title, decodedPayload.primaryAction?.title)
        XCTAssertEqual(payload.primaryAction?.link, decodedPayload.primaryAction?.link)
    }
}
