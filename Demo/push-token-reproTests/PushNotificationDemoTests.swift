//
//  PushNotificationDemoTests.swift
//  Ortto iOS SDK Push Demo
//
//  Unit tests for the Ortto iOS SDK demo app.
//

import XCTest
@testable import PushNotificationDemo_APNS

final class PushNotificationDemoTests: XCTestCase {

    func testPushProviderTokenTypesMatchSDKValues() {
        XCTAssertEqual(PushProvider.apns.tokenType, "apn")
        XCTAssertEqual(PushProvider.fcm.tokenType, "fcm")
    }

    func testProviderTitlesAreCustomerReadable() {
        XCTAssertEqual(PushProvider.apns.title, "Apple Push Notification service")
        XCTAssertEqual(PushProvider.fcm.title, "Firebase Cloud Messaging")
    }
}
