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

final class PushMessagingRegistrationTests: OrttoTestCase {

    private let token = PushToken(value: "device-token", type: "apns")

    private var mock: RecordingApiManager!
    private var savedApiManager: ApiManagerInterface!
    private var savedPreferences: PreferencesInterface!
    private var savedUserStorage: UserStorage!

    override func setUp() {
        super.setUp()

        // Isolate global SDK state so each test starts from a clean slate.
        savedApiManager = Ortto.shared.apiManager
        savedPreferences = Ortto.shared.preferences
        savedUserStorage = Ortto.shared.userStorage

        let preferences = OrttoPreferencesManager()
        preferences.clear()
        Ortto.shared.preferences = preferences
        Ortto.shared.userStorage = OrttoUserStorage(preferences)

        mock = RecordingApiManager()
        Ortto.shared.apiManager = mock

        // .Accept resolves synchronously without touching UNUserNotificationCenter.
        PushMessaging.shared.permission = .Accept
    }

    override func tearDown() {
        Ortto.shared.preferences.clear()
        Ortto.shared.apiManager = savedApiManager
        Ortto.shared.preferences = savedPreferences
        Ortto.shared.userStorage = savedUserStorage
        super.tearDown()
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

        XCTAssertEqual(Ortto.shared.userStorage.session, "srv-session")
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

    /// An expectation satisfied once the session the server returned has been persisted —
    /// proof that a registration round-tripped (send + completion) successfully.
    private func registeredExpectation() -> XCTestExpectation {
        XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                Ortto.shared.userStorage.session == "srv-session"
            },
            object: nil
        )
    }
}

/// Drives reconciliation deterministically: counts push-permission sends, lets a test toggle
/// success/failure, and returns the canned `session_id` the assertions key off.
private final class RecordingApiManager: ApiManagerInterface {
    var appKey: String? = "app-key"
    var shouldSucceed = true
    var onSend: (() -> Void)?

    func sendRegisterIdentity(_: UserStorage) async throws -> IdentityRegistrationResponse? {
        nil
    }

    func sendLinkTracking(_: URL) async throws {}

    func send<R: OrttoAPIRequest>(_: R) async throws -> R.Response {
        onSend?()
        guard shouldSucceed else {
            throw OrttoHTTPError.network(URLError(.timedOut))
        }
        let json = Data(#"{"session_id":"srv-session"}"#.utf8)
        return try JSONDecoder().decode(R.Response.self, from: json)
    }
}
