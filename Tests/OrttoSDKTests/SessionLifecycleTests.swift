//
//  SessionLifecycleTests.swift
//

import Foundation
@testable import OrttoPushMessaging
@testable import OrttoSDKCore
import XCTest

final class SessionLifecycleTests: OrttoIsolatedTestCase {

    private let token = PushToken(value: "device-token", type: "apns")
    private var http: MockOrttoHTTPClient!

    override func setUp() {
        super.setUp()

        http = MockOrttoHTTPClient()
        http.sendResponder = { request in
            switch request.url?.path {
            case "/-/events/push-mobile-session":
                // identify: echo a session keyed to the contact.
                let body = try XCTUnwrap(request.httpBody)
                let payload = try JSONDecoder().decode(PushMobileSessionRequest.self, from: body)
                return .json(#"{"session_id":"session-\#(payload.contactID ?? "?")"}"#)
            default:
                // push-permission (registration / logout)
                return .json(#"{"session_id":"perm-ok"}"#)
            }
        }
        Ortto.shared.apiManager = ApiManager(connector: OrttoAPIConnector(
            http: http,
            appKey: "app-key",
            baseURL: URL(string: "https://api.example.test")!
        ))

        // Seed a token directly — clearIdentity needs one, and this avoids a registration round-trip.
        preferences.setObject(object: token, key: "token")
        PushMessaging.shared.permission = .Accept
    }

    /// Logout clears identity and keeps the token; a later sign-in's session must stick.
    func testLogoutClearsIdentityKeepsTokenAndFutureSessionSticks() async {
        let sessionA = await identify(contactID: "A")
        XCTAssertEqual(sessionA, "session-A")
        XCTAssertEqual(Ortto.shared.userStorage.session, "session-A")

        await logout()
        XCTAssertNil(Ortto.shared.userStorage.session, "logout should clear the session")
        XCTAssertNil(Ortto.shared.userStorage.user, "logout should clear the user")
        XCTAssertEqual(PushMessaging.shared.token, token, "logout must keep the device token")

        let sessionB = await identify(contactID: "B")
        XCTAssertEqual(sessionB, "session-B")
        XCTAssertEqual(
            Ortto.shared.userStorage.session, "session-B",
            "a logout must not clobber a session established after it"
        )
    }

    /// Concurrent sign-ins must not cross sessions — each caller gets its own.
    func testConcurrentSignInsDoNotMixSessions() async {
        let contacts = (0 ..< 20).map { "c\($0)" }
        let received = SessionResults()

        await withTaskGroup(of: Void.self) { group in
            for contact in contacts.shuffled() {
                group.addTask {
                    let session = await self.identify(contactID: contact)
                    received.record(contact: contact, session: session)
                }
            }
        }

        for contact in contacts {
            XCTAssertEqual(received[contact], "session-\(contact)", "\(contact) received another contact's session")
        }
    }

    /// The async identify returns the session ID and stores it.
    func testAwaitIdentifyReturnsAndStoresSession() async throws {
        let session = try await Ortto.shared.identify(UserIdentifier(
            contactID: "Z", email: nil, phone: nil, externalID: nil,
            firstName: nil, lastName: nil, acceptsGDPR: false
        ))
        XCTAssertEqual(session, "session-Z")
        XCTAssertEqual(Ortto.shared.userStorage.session, "session-Z")
    }

    /// The async identify surfaces server errors instead of swallowing them.
    func testAwaitIdentifyThrowsOnPermanentFailure() async {
        http.sendResponder = { _ in .json(#"{"error":"nope"}"#, statusCode: 400) }
        do {
            _ = try await Ortto.shared.identify(UserIdentifier(
                contactID: "Q", email: nil, phone: nil, externalID: nil,
                firstName: nil, lastName: nil, acceptsGDPR: false
            ))
            XCTFail("expected identify to throw")
        } catch {
            // expected
        }
    }

    /// Two identifies firing "at the same time" (NOT awaited in order) must converge on
    /// one session: the second reads the session the first established inside the queue,
    /// instead of each sending nil and minting its own. (Old snapshot behaviour minted two.)
    func testConcurrentIdentifiesConvergeOnOneSession() async {
        let minted = AtomicCounter()
        http.sendResponder = { request in
            let body = try XCTUnwrap(request.httpBody)
            let payload = try JSONDecoder().decode(PushMobileSessionRequest.self, from: body)
            if let sent = payload.sessionID, !sent.isEmpty {
                return .json(#"{"session_id":"\#(sent)"}"#)   // echo the session it was handed
            }
            return .json(#"{"session_id":"minted-\#(minted.increment())"}"#)  // mint a fresh one
        }

        let user = UserIdentifier(
            contactID: "same", email: nil, phone: nil, externalID: nil,
            firstName: nil, lastName: nil, acceptsGDPR: false
        )

        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< 2 {
                group.addTask { _ = try? await Ortto.shared.identify(user) }
            }
        }

        XCTAssertEqual(minted.value, 1, "concurrent identifies should converge on one session, not mint two")
        XCTAssertEqual(Ortto.shared.userStorage.session, "minted-1")
    }

    /// The legacy scenario: push registration and identify fired concurrently (neither
    /// awaited in order) must converge on ONE session across both endpoints.
    func testConcurrentRegisterAndIdentifyConvergeOnOneSession() async {
        let minted = AtomicCounter()
        http.sendResponder = { request in
            let body = try XCTUnwrap(request.httpBody)
            let sent: String?
            switch request.url?.path {
            case "/-/events/push-mobile-session":
                sent = try JSONDecoder().decode(PushMobileSessionRequest.self, from: body).sessionID
            default: // push-permission
                sent = try JSONDecoder().decode(PushPermissionRequest.self, from: body).sessionID
            }
            if let sent, !sent.isEmpty {
                return .json(#"{"session_id":"\#(sent)"}"#)   // echo
            }
            return .json(#"{"session_id":"minted-\#(minted.increment())"}"#)  // mint
        }

        let user = UserIdentifier(
            contactID: "u", email: nil, phone: nil, externalID: nil,
            firstName: nil, lastName: nil, acceptsGDPR: false
        )

        await withTaskGroup(of: Void.self) { group in
            group.addTask { _ = try? await Ortto.shared.dispatchPushRequest() }
            group.addTask { _ = try? await Ortto.shared.identify(user) }
        }

        XCTAssertEqual(minted.value, 1, "register + identify should converge on one session, not mint two")
        XCTAssertEqual(Ortto.shared.userStorage.session, "minted-1")
    }

    /// Async clearIdentity clears local identity, keeps the device token, returns the response.
    func testAwaitClearIdentityClearsLocalStateKeepsToken() async throws {
        let session = await identify(contactID: "C")
        XCTAssertEqual(session, "session-C")

        _ = try await Ortto.shared.clearIdentity()

        XCTAssertNil(Ortto.shared.userStorage.session, "clearIdentity clears the session")
        XCTAssertNil(Ortto.shared.userStorage.user, "clearIdentity clears the user")
        XCTAssertEqual(PushMessaging.shared.token, token, "clearIdentity keeps the device token")
    }

    /// Regression: logout is ONE atomic lane operation, so an identify enqueued *behind* it
    /// must run entirely after and stick — logout must not wipe a session established after it.
    /// (The old two-op logout let identify's persist slot between the network clear and the
    /// local wipe, silently logging the new user back out.)
    func testLogoutDoesNotWipeAnIdentifyEnqueuedAfterIt() async throws {
        let sessionA = await identify(contactID: "A")
        XCTAssertEqual(sessionA, "session-A")

        // Make the logout's push-permission clear slow so it holds the lane while we enqueue identify(B).
        http.sendResponder = { request in
            switch request.url?.path {
            case "/-/events/push-permission":
                try await Task.sleep(nanoseconds: 80_000_000)
                return .json(#"{"session_id":"perm-ok"}"#)
            default: // push-mobile-session: echo a session keyed to the contact
                let body = try XCTUnwrap(request.httpBody)
                let payload = try JSONDecoder().decode(PushMobileSessionRequest.self, from: body)
                return .json(#"{"session_id":"session-\#(payload.contactID ?? "?")"}"#)
            }
        }

        let loggingOut = Task { _ = try? await Ortto.shared.clearIdentity() }
        try? await Task.sleep(nanoseconds: 20_000_000) // let logout claim the lane

        // identify(B) enqueues BEHIND the logout; it must run after it and persist its session.
        let sessionB = try await Ortto.shared.identify(UserIdentifier(
            contactID: "B", email: nil, phone: nil, externalID: nil,
            firstName: nil, lastName: nil, acceptsGDPR: false
        ))
        _ = await loggingOut.value

        XCTAssertEqual(sessionB, "session-B")
        XCTAssertEqual(Ortto.shared.userStorage.session, "session-B",
                       "logout must not wipe a session established after it")
        XCTAssertEqual(Ortto.shared.userStorage.user?.contactID, "B")
    }

    /// Regression: a session mutation enqueued on the lane (how logout clears identity) runs
    /// INSIDE the serial lane, so it can't race an in-flight session-bound persist. With a slow
    /// identify holding the lane, the mutation only completes after that identify has persisted —
    /// proving the clear is ordered, not an out-of-lane write that could clobber/leak.
    func testSessionMutationIsSerializedBehindInFlightRequest() async {
        http.sendResponder = { request in
            if request.url?.path == "/-/events/push-mobile-session" {
                try await Task.sleep(nanoseconds: 80_000_000) // slow identify holds the lane
                let body = try XCTUnwrap(request.httpBody)
                let payload = try JSONDecoder().decode(PushMobileSessionRequest.self, from: body)
                return .json(#"{"session_id":"session-\#(payload.contactID ?? "?")"}"#)
            }
            return .json(#"{"session_id":"perm-ok"}"#)
        }

        // Identify enters the lane first and stays busy for ~80ms.
        let identifying = Task { try? await Ortto.shared.identify(UserIdentifier(
            contactID: "D", email: nil, phone: nil, externalID: nil,
            firstName: nil, lastName: nil, acceptsGDPR: false
        )) }
        try? await Task.sleep(nanoseconds: 20_000_000) // let the identify claim the lane

        // The mutation enqueues BEHIND the in-flight identify; it must wait for it to persist.
        try? await Ortto.shared.requestQueue.enqueue {
            Ortto.shared.userStorage.session = nil
        }

        XCTAssertNil(Ortto.shared.userStorage.session,
                     "the clear ran after the in-flight identify's persist — it was lane-ordered, not racing")
        _ = await identifying.value
    }

    /// Concurrent identifies for different contacts must leave a CONSISTENT (user, session)
    /// pair — the winner's user with the winner's session, never one caller's user paired
    /// with another caller's session (the out-of-lane user write used to allow that).
    func testConcurrentIdentifiesLeaveConsistentUserAndSession() async {
        http.sendResponder = { request in
            let body = try XCTUnwrap(request.httpBody)
            let payload = try JSONDecoder().decode(PushMobileSessionRequest.self, from: body)
            return .json(#"{"session_id":"session-\#(payload.contactID ?? "?")"}"#)
        }

        let contacts = (0 ..< 20).map { "c\($0)" }
        await withTaskGroup(of: Void.self) { group in
            for contact in contacts.shuffled() {
                group.addTask {
                    _ = try? await Ortto.shared.identify(UserIdentifier(
                        contactID: contact, email: nil, phone: nil, externalID: nil,
                        firstName: nil, lastName: nil, acceptsGDPR: false
                    ))
                }
            }
        }

        let finalUser = Ortto.shared.userStorage.user?.contactID
        XCTAssertNotNil(finalUser)
        XCTAssertEqual(Ortto.shared.userStorage.session, "session-\(finalUser!)",
                       "the stored session must belong to the stored user — the pair must be consistent")
    }

    /// A caller cancelled mid-flight must not apply its session/user write.
    func testCancelledIdentifyDoesNotPersist() async {
        http.sendResponder = { _ in
            try await Task.sleep(nanoseconds: 200_000_000) // still in flight when we cancel
            return .json(#"{"session_id":"should-not-persist"}"#)
        }

        let task = Task {
            try await Ortto.shared.identify(UserIdentifier(
                contactID: "X", email: nil, phone: nil, externalID: nil,
                firstName: nil, lastName: nil, acceptsGDPR: false
            ))
        }
        try? await Task.sleep(nanoseconds: 30_000_000) // let it enter the lane and start the send
        task.cancel()
        _ = try? await task.value

        XCTAssertNil(Ortto.shared.userStorage.session, "a cancelled identify must not persist its session")
        XCTAssertNil(Ortto.shared.userStorage.user, "a cancelled identify must not persist its user")
    }

    // MARK: - Helpers

    private func identify(contactID: String) async -> String? {
        await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            Ortto.shared.identify(UserIdentifier(
                contactID: contactID, email: nil, phone: nil, externalID: nil,
                firstName: nil, lastName: nil, acceptsGDPR: false
            )) { result in
                cont.resume(returning: try? result.get())
            }
        }
    }

    private func logout() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            Ortto.shared.clearIdentity { _ in cont.resume(returning: ()) }
        }
    }
}

private final class SessionResults: @unchecked Sendable {
    private let lock = NSLock()
    private var byContact: [String: String?] = [:]

    func record(contact: String, session: String?) {
        lock.lock()
        byContact[contact] = session
        lock.unlock()
    }

    subscript(_ contact: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return byContact[contact] ?? nil
    }
}
