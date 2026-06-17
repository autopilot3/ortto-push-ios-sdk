//
//  PushNotificationDemoUITests.swift
//  Ortto iOS SDK Push Demo
//
//  UI tests for the Ortto iOS SDK demo app.
//

import XCTest

final class PushNotificationDemoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsLoginExperience() {
        let app = XCUIApplication()
        // Override the persisted session (NSArgumentDomain) so the login
        // screen shows even when the simulator has a signed-in account.
        app.launchArguments += ["-OrttoPushDemo.signedInEmail", ""]
        app.launch()

        XCTAssertTrue(app.staticTexts["Push Demo"].waitForExistence(timeout: 5))
    }
}
