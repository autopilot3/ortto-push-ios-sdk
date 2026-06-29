//
//  ApiManagerHTTPTests.swift
//
//  Created on 25/5/2026.
//

import Foundation
@testable import OrttoSDKCore
import XCTest

final class ApiManagerHTTPTests: OrttoIsolatedTestCase {

    private let baseURL = URL(string: "https://api.example.test")!

    private func makeApiManager(http: MockOrttoHTTPClient) -> ApiManager {
        ApiManager(connector: OrttoAPIConnector(
            http: http,
            appKey: "app-key",
            baseURL: baseURL
        ))
    }

    // MARK: - Register identity (via send)

    func testRegisterIdentitySendsExpectedRequest() async throws {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)

        // The request carries the live session from userStorage (injected inside the queue).
        Ortto.shared.userStorage.session = "existing-session"

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

        let response = try await api.send(RegisterIdentityRequest(
            user: UserIdentifier(
                contactID: "contact-id", email: "person@example.test", phone: nil,
                externalID: nil, firstName: "First", lastName: "Last", acceptsGDPR: true
            ),
            appKey: "app-key",
            shouldSkipNonExistingContacts: false
        ))

        XCTAssertEqual(response.sessionID, "new-session")
        XCTAssertEqual(http.sentRequests.count, 1)
    }

    func testRegisterIdentityThrowsServerErrorOnNon2xx() async throws {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)

        http.sendResponder = { request in
            .json(#"{"error":"forbidden"}"#, statusCode: 403, url: request.url)
        }

        do {
            _ = try await api.send(RegisterIdentityRequest(
                user: UserIdentifier(contactID: "c", email: nil, phone: nil, externalID: nil,
                                     firstName: nil, lastName: nil, acceptsGDPR: false),
                appKey: "app-key",
                shouldSkipNonExistingContacts: false
            ))
            XCTFail("Expected OrttoAPIError.server")
        } catch OrttoAPIError.server(let statusCode, let message, _) {
            XCTAssertEqual(statusCode, 403)
            XCTAssertEqual(message, "forbidden")
        }
    }

    // MARK: - Link tracking (via send)

    func testLinkTrackingFiresGetToExactURL() async throws {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let trackingURL = URL(string: "https://tracking.example.test/open")!

        http.sendResponder = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url, trackingURL)
            return .json("{}", statusCode: 204, url: request.url)
        }

        _ = try await api.send(LinkTrackingRequest(trackingURL: trackingURL))

        XCTAssertEqual(http.sentRequests.count, 1)
    }
}
