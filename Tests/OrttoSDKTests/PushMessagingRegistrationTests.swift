//
//  PushMessagingRegistrationTests.swift
//
//  Covers token registration: a failed first attempt must keep the cached token so a
//  later trigger (e.g. identity/session arriving) can retry, while a steady-state
//  re-check must not re-send and spam duplicate registration events.
//

import Foundation
@testable import OrttoPushMessaging
@testable import OrttoSDKCore
import XCTest

final class PushMessagingRegistrationTests: OrttoIsolatedTestCase {

    private let token = PushToken(value: "device-token", type: "apns")

    private var mock: MockApiManager!

    override func setUp() {
        super.setUp()

        mock = MockApiManager()
        Ortto.shared.apiManager = mock

        // .Accept resolves synchronously without touching UNUserNotificationCenter.
        PushMessaging.shared.permission = .Accept
    }

    /// The core regression: if the first registration fails, the token must be kept and a
    /// later re-check must retry it — without the app having to supply the token again.
    func testFailedFirstRegistrationIsRetriedOnNextRequest() {
        // 1. First attempt fails.
        mock.shouldSucceed = false
        let firstAttempt = expectation(description: "first registration attempt")
        mock.onSend = { firstAttempt.fulfill() }

        PushMessaging.shared.token = token
        wait(for: [firstAttempt], timeout: 2)

        // Token is still known despite the failure, and nothing got registered.
        XCTAssertEqual(PushMessaging.shared.token, token)
        XCTAssertNil(Ortto.shared.userStorage.session)

        // 2. Session/identity becomes available → the next request retries and now succeeds.
        mock.onSend = nil
        mock.shouldSucceed = true
        let registered = registeredExpectation()

        Ortto.shared.dispatchPushRequest()
        wait(for: [registered], timeout: 2)

        XCTAssertEqual(Ortto.shared.userStorage.session, "mock-session")
    }

    /// The same token arriving again (e.g. on the next launch) must not re-register — otherwise
    /// every launch would create a duplicate registration event server-side.
    func testSameTokenArrivingAgainIsNotReRegistered() {
        mock.shouldSucceed = true
        let registered = registeredExpectation()

        PushMessaging.shared.token = token
        wait(for: [registered], timeout: 2)

        let noFurtherSend = expectation(description: "no further registration")
        noFurtherSend.isInverted = true
        mock.onSend = { noFurtherSend.fulfill() }

        PushMessaging.shared.token = token
        wait(for: [noFurtherSend], timeout: 0.5)
    }

    /// Logout clears the identity and the registration record but keeps the device token, so the
    /// next user re-registers the same device instead of being stuck with no token until the OS
    /// re-delivers it. (The prior contact is disabled by clearIdentity's permission:false call.)
    func testLogoutKeepsDeviceTokenAndReRegistersForNextUser() {
        mock.shouldSucceed = true

        // Register for the first user.
        let registered = registeredExpectation()
        PushMessaging.shared.token = token
        wait(for: [registered], timeout: 2)
        XCTAssertEqual(Ortto.shared.userStorage.session, "mock-session")

        // Log out.
        let loggedOut = expectation(description: "logout")
        Ortto.shared.clearIdentity { _ in loggedOut.fulfill() }
        wait(for: [loggedOut], timeout: 2)

        // Device token survives; identity is gone.
        XCTAssertEqual(PushMessaging.shared.token, token)
        XCTAssertNil(Ortto.shared.userStorage.session)

        // A different user identifies → the same token re-registers (record was cleared, no skip).
        Ortto.shared.userStorage.session = "user-b-session"
        let reRegister = expectation(description: "re-register for next user")
        mock.onSend = { reRegister.fulfill() }
        Ortto.shared.dispatchPushRequest()
        wait(for: [reRegister], timeout: 2)
    }

    /// The awaitable `dispatchPushRequest` registers the stored token, returns the
    /// response, and dedups a second call for the same token.
    func testAwaitDispatchPushRequestRegistersThenDedups() async throws {
        mock.shouldSucceed = true
        // Seed the token directly to avoid the setter's fire-and-forget registration.
        Ortto.shared.preferences.setObject(object: token, key: "token")

        let response = try await Ortto.shared.dispatchPushRequest()
        XCTAssertEqual(response?.sessionId, "mock-session")
        XCTAssertEqual(Ortto.shared.userStorage.session, "mock-session")

        // Same token already registered → no further send, returns nil.
        let noFurtherSend = expectation(description: "no further registration")
        noFurtherSend.isInverted = true
        mock.onSend = { noFurtherSend.fulfill() }

        let second = try await Ortto.shared.dispatchPushRequest()
        XCTAssertNil(second)
        await fulfillment(of: [noFurtherSend], timeout: 0.3)
    }

    /// An expectation satisfied once the session the mock returned has been persisted —
    /// proof that a registration round-tripped (send + completion) successfully.
    private func registeredExpectation() -> XCTestExpectation {
        XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                Ortto.shared.userStorage.session == "mock-session"
            },
            object: nil
        )
    }
}
