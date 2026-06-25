//
//  PushDemoTests.swift
//  Ortto iOS SDK Push Demo
//
//  Unit tests for the Ortto iOS SDK demo app.
//

import XCTest
@testable import PushDemo_APNS

final class PushDemoTests: XCTestCase {

    func testPushProviderTokenTypesMatchSDKValues() {
        XCTAssertEqual(PushProvider.apns.tokenType, "apn")
        XCTAssertEqual(PushProvider.fcm.tokenType, "fcm")
    }

    func testProviderTitlesAreCustomerReadable() {
        XCTAssertEqual(PushProvider.apns.title, "Apple Push Notification service")
        XCTAssertEqual(PushProvider.fcm.title, "Firebase Cloud Messaging")
    }
}

// MARK: - End-to-end happy path
//
//  One app-hosted integration test that drives the real SDK through every
//  integration point the demo wires up (the `// Ortto SDK:` touchpoints in
//  PushDemoApp.swift), against an in-process stub HTTP client and in-memory
//  preferences — no network, no real APNs, fully deterministic.
//
//  Why app-hosted (not XCUITest): this runs inside the app process, so it can
//  inject `Ortto.shared.apiManager` / `.preferences` and assert directly on
//  in-process state (session id, cached token, enriched notification content)
//  instead of black-boxing the UI.

@preconcurrency import OrttoSDKCore
@preconcurrency import OrttoPushMessaging
@preconcurrency import OrttoPushMessagingAPNS
import UserNotifications

final class OrttoEndToEndHappyPathTests: XCTestCase {

    private var http: RecordingHTTPClient!
    private var prefs: InMemoryPreferences!

    override func setUp() {
        super.setUp()
        prefs = InMemoryPreferences()
        http = RecordingHTTPClient()

        // Swap the SDK's collaborators for in-process fakes. All three are public
        // `var`s on the singleton, which is the whole reason this is testable.
        Ortto.shared.preferences = prefs
        Ortto.shared.userStorage = InMemoryUserStorage(prefs)
        Ortto.shared.apiManager = ApiManager(
            connector: OrttoAPIConnector(
                http: http,
                appKey: "test-app-key",
                baseURL: URL(string: "https://stub.ortto.test")!
            )
        )
    }

    func testFullHappyPathHitsEverySDKSurface() throws {
        // 1. identify ----------------------------------------------------------
        let identified = expectation(description: "identify completes")
        Ortto.shared.identify(
            UserIdentifier(
                contactID: nil,
                email: "e2e@example.test",
                phone: nil,
                externalID: nil,
                firstName: "E2E",
                lastName: "Tester"
            )
        ) { result in
            if case .success = result { identified.fulfill() }
        }
        wait(for: [identified], timeout: 5)

        XCTAssertEqual(Ortto.shared.userStorage.session, "sess-identify")
        XCTAssertTrue(
            http.paths.contains { $0.contains("push-mobile-session") },
            "identify should POST the identity/session endpoint"
        )

        // 2. register push token -----------------------------------------------
        // Synthesize the AppDelegate's didRegisterForRemoteNotifications callback.
        let apnsToken = Data([0xAB, 0xCD, 0xEF, 0x01])
        PushMessaging.shared.registerDeviceToken(apnsToken: apnsToken)

        waitUntil("token is cached after a successful registration") {
            PushMessaging.shared.token?.value == "abcdef01"
        }
        XCTAssertEqual(PushMessaging.shared.token?.type, "apn")
        XCTAssertTrue(
            http.paths.contains { $0.contains("push-permission") },
            "registering a token should POST push-permission"
        )

        // 3. force re-dispatch (the `force` path) ------------------------------
        // The token is unchanged, but a re-dispatch must still re-send (this is the
        // bug PR #47 fixes — unchanged token + new session must reach the server).
        let permissionCallsBefore = permissionCallCount()
        Ortto.shared.dispatchPushRequest()
        waitUntil("re-dispatch re-sends despite an unchanged token") {
            self.permissionCallCount() > permissionCallsBefore
        }

        // 4. screen view (local surface, no network) ---------------------------
        Ortto.shared.screen("Home")

        // 5. UTM extraction + click tracking -----------------------------------
        let trackingURL = "https://track.ortto.test/c?mid=abc"
        let deeplink = makeTrackedDeeplink(
            trackingURL: trackingURL,
            extraQuery: "utm_source=ortto&utm_campaign=demo"
        )

        let utm = Ortto.shared.retrieveUtmParameters(deeplink)
        XCTAssertEqual(utm?.source, "ortto")
        XCTAssertEqual(utm?.campaign, "demo")

        let tracked = expectation(description: "trackLinkClick completes")
        Ortto.shared.trackLinkClick(deeplink) { tracked.fulfill() }
        wait(for: [tracked], timeout: 5)
        XCTAssertTrue(
            http.paths.contains { $0.hasSuffix("/c") },
            "click tracking should GET the decoded tracking_url"
        )

        // 6. rich push enrichment (NSE) ----------------------------------------
        try assertRichPushEnrichmentKeepsDistinctLinks()

        // 7. clear identity / logout -------------------------------------------
        // Sends permission=false for the current token, then wipes local state.
        let cleared = expectation(description: "clearIdentity completes")
        Ortto.shared.clearIdentity { _ in cleared.fulfill() }
        wait(for: [cleared], timeout: 5)

        XCTAssertNil(PushMessaging.shared.token, "logout should clear the cached token")
        XCTAssertNil(Ortto.shared.userStorage.session, "logout should clear the session")
    }

    // MARK: - Rich push (NSE) surface

    /// Drives `MessagingService.shared.didReceive` (the call the NSE makes) and
    /// asserts the duplicate-`action`-type fix from PR #45: two `"page"` buttons
    /// get distinct per-index identifiers and both links survive. The links live
    /// in the delivered content's `userInfo` under `<categoryID>.<index>`.
    private func assertRichPushEnrichmentKeepsDistinctLinks() throws {
        let content = UNMutableNotificationContent()
        content.userInfo = [
            "ortto_notification_id": "e2e-rich",
            "title": "Rich",
            "body": "Body",
            "actions": """
                [
                    {"action":"page","title":"One","link":"ortto://one"},
                    {"action":"page","title":"Two","link":"ortto://two"}
                ]
                """
        ]
        let request = UNNotificationRequest(identifier: "e2e-rich-req", content: content, trigger: nil)

        let delivered = expectation(description: "rich push delivered")
        let box = Box<UNNotificationContent?>(nil)
        XCTAssertTrue(MessagingService.shared.didReceive(request) { content in
            box.value = content
            delivered.fulfill()
        })
        wait(for: [delivered], timeout: 5)

        let deliveredContent = try XCTUnwrap(box.value)
        let categoryID = deliveredContent.categoryIdentifier
        let userInfo = try XCTUnwrap(deliveredContent.userInfo as? [String: String])
        XCTAssertEqual(
            [userInfo["\(categoryID).0"], userInfo["\(categoryID).1"]],
            ["ortto://one", "ortto://two"],
            "each button keeps its own link; duplicate action types must not collide"
        )
    }

    // MARK: - Helpers

    private func permissionCallCount() -> Int {
        http.paths.filter { $0.contains("push-permission") }.count
    }

    /// Builds a deeplink whose `tracking_url` is base64url-encoded the way Ortto
    /// emits it, plus any extra query (e.g. utm_*) on the deeplink itself.
    private func makeTrackedDeeplink(trackingURL: String, extraQuery: String) -> String {
        let b64url = Data(trackingURL.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "pushdemo://open?tracking_url=\(b64url)&\(extraQuery)"
    }

    /// Spins the run loop until `predicate` is true or the timeout elapses. Used for
    /// the fire-and-forget SDK calls that have no completion handler.
    private func waitUntil(
        _ description: String,
        timeout: TimeInterval = 5,
        _ predicate: () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate() {
            if Date() > deadline {
                XCTFail("Timed out waiting for: \(description)")
                return
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }
}

// MARK: - Test doubles

/// A tiny thread-safe box so escaping SDK callbacks (which may fire off the main
/// actor) can hand a value back to the test without a data race.
private final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T
    init(_ value: T) { stored = value }
    var value: T {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
    }
}

/// Records outgoing requests and returns canned, decodable responses by path.
private final class RecordingHTTPClient: OrttoHTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []

    /// Synchronous so the lock is never taken inside the `async` `send`.
    private func record(_ request: URLRequest) {
        lock.lock(); requests.append(request); lock.unlock()
    }

    var paths: [String] {
        lock.lock(); defer { lock.unlock() }
        return requests.compactMap { $0.url?.path }
    }

    func send(_ request: URLRequest) async throws -> OrttoHTTPResponse {
        record(request)

        let path = request.url?.path ?? ""
        let body: String
        if path.contains("push-mobile-session") {
            body = #"{"session_id":"sess-identify"}"#
        } else if path.contains("push-permission") {
            body = #"{"session_id":"sess-push"}"#
        } else {
            body = "{}" // tracking GET and anything else
        }

        return OrttoHTTPResponse(
            data: Data(body.utf8),
            response: HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
    }

    func downloadFile(from url: URL, kind: OrttoDownloadKind) async throws -> OrttoDownloadedFile {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ortto-e2e", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("\(UUID().uuidString).png")
        try Self.tinyPNG.write(to: fileURL, options: .atomic)
        return OrttoDownloadedFile(
            url: fileURL,
            response: HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        )
    }

    private static let tinyPNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
    )!
}

/// PreferencesInterface backed by a dictionary — same encode/decode semantics as
/// the real OrttoPreferencesManager, but no UserDefaults persistence between runs.
/// Locked because the registration completion writes the token off the main actor
/// while the test polls it on the main actor.
private final class InMemoryPreferences: PreferencesInterface, @unchecked Sendable {
    private let lock = NSLock()
    private var strings: [String: String] = [:]
    private var objects: [String: Data] = [:]

    func getString(_ key: String) -> String? {
        lock.lock(); defer { lock.unlock() }
        return strings[key]
    }

    func setString(_ value: String, key: String) {
        lock.lock(); strings[key] = value; lock.unlock()
    }

    func removeString(_ key: String) {
        lock.lock(); strings[key] = nil; objects[key] = nil; lock.unlock()
    }

    func getObject<T: Codable>(key: String, type: T.Type) -> T? {
        lock.lock(); let data = objects[key]; lock.unlock()
        guard let data else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func setObject(object: Codable, key: String) {
        let data = try? JSONEncoder().encode(object)
        lock.lock(); objects[key] = data; lock.unlock()
    }

    func clear() {
        lock.lock(); strings.removeAll(); objects.removeAll(); lock.unlock()
    }
}

/// UserStorage mirroring OrttoUserStorage (which is internal), backed by the same
/// preferences so `clearData()` clears the session too.
private final class InMemoryUserStorage: UserStorage, @unchecked Sendable {
    private let prefs: PreferencesInterface
    init(_ prefs: PreferencesInterface) { self.prefs = prefs }

    var user: UserIdentifier? {
        get { prefs.getObject(key: "user", type: UserIdentifier.self) }
        set { prefs.setObject(object: newValue, key: "user") }
    }

    var session: String? {
        get { prefs.getString("sessionID") }
        set {
            guard let value = newValue else { prefs.removeString("sessionID"); return }
            prefs.setString(value, key: "sessionID")
        }
    }
}
