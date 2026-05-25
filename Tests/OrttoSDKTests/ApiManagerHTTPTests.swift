//
//  ApiManagerHTTPTests.swift
//
//  Created on 25/5/2026.
//

import Foundation
@testable import OrttoSDKCore
import XCTest

final class ApiManagerHTTPTests: OrttoTestCase {

    private let baseURL = URL(string: "https://api.example.test")!

    private func makeApiManager(http: MockOrttoHTTPClient) -> ApiManager {
        ApiManager(connector: OrttoAPIConnector(
            http: http,
            appKey: "app-key",
            baseURL: baseURL
        ))
    }

    // MARK: - Register identity

    func testSendRegisterIdentitySendsExpectedRequest() async throws {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)

        let storage = TestUserStorage(
            user: UserIdentifier(
                contactID: "contact-id",
                email: "person@example.test",
                phone: nil,
                externalID: nil,
                firstName: "First",
                lastName: "Last",
                acceptsGDPR: true
            ),
            session: "existing-session"
        )

        http.sendResponder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/-/events/push-mobile-session")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(request.httpBody)
            let payload = try JSONDecoder().decode(PushMobileSessionRequest.self, from: body)
            XCTAssertEqual(payload.appKey, "app-key")
            XCTAssertEqual(payload.contactID, "contact-id")
            XCTAssertEqual(payload.sessionID, "existing-session")
            XCTAssertEqual(payload.platform, "ios")

            return .json(#"{"session_id":"new-session"}"#, url: request.url)
        }

        let response = try await api.sendRegisterIdentity(storage)

        XCTAssertEqual(response?.sessionID, "new-session")
        XCTAssertEqual(http.sentRequests.count, 1)
    }

    func testSendRegisterIdentityReturnsNilWhenNoUserIdentified() async throws {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let storage = TestUserStorage(user: nil, session: nil)

        let response = try await api.sendRegisterIdentity(storage)

        XCTAssertNil(response)
        XCTAssertEqual(http.sentRequests.count, 0)
    }

    func testSendRegisterIdentityThrowsServerErrorOnNon2xx() async throws {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let storage = TestUserStorage(
            user: UserIdentifier(contactID: "c", email: nil, phone: nil, externalID: nil,
                                 firstName: nil, lastName: nil, acceptsGDPR: false),
            session: nil
        )

        http.sendResponder = { request in
            .json(#"{"error":"forbidden"}"#, statusCode: 403, url: request.url)
        }

        do {
            _ = try await api.sendRegisterIdentity(storage)
            XCTFail("Expected OrttoAPIError.server")
        } catch OrttoAPIError.server(let statusCode, let message, _) {
            XCTAssertEqual(statusCode, 403)
            XCTAssertEqual(message, "forbidden")
        }
    }

    // MARK: - Link tracking

    func testSendLinkTrackingFiresGetToExactURL() async throws {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let trackingURL = URL(string: "https://tracking.example.test/open")!

        http.sendResponder = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url, trackingURL)
            return .json("{}", statusCode: 204, url: request.url)
        }

        try await api.sendLinkTracking(trackingURL)

        XCTAssertEqual(http.sentRequests.count, 1)
    }
}

private struct TestUserStorage: UserStorage {
    var user: UserIdentifier?
    var session: String?
}
