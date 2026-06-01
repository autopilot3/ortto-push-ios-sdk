//
//  PushPermissionHTTPTests.swift
//
//  Created on 25/5/2026.
//

import Foundation
@testable import OrttoPushMessaging
@testable import OrttoSDKCore
import XCTest

final class PushPermissionHTTPTests: OrttoTestCase {

    private let baseURL = URL(string: "https://api.example.test")!
    private let token = PushToken(value: "device-token", type: "apns")

    private func makeApiManager(http: MockOrttoHTTPClient) -> ApiManager {
        ApiManager(connector: OrttoAPIConnector(
            http: http,
            appKey: "app-key",
            baseURL: baseURL
        ))
    }

    // MARK: - Request shape

    func testSendPushPermissionSendsExpectedRequest() async throws {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)

        http.sendResponder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/-/events/push-permission")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(request.httpBody)
            let payload = try JSONDecoder().decode(PushPermissionRequest.self, from: body)
            XCTAssertEqual(payload.appKey, "app-key")
            XCTAssertEqual(payload.sessionID, "session-id")
            XCTAssertEqual(payload.deviceToken, "device-token")
            XCTAssertEqual(payload.pushTokenType, "apns")
            XCTAssertTrue(payload.permission)

            return .json(#"{"session_id":"registered-session"}"#, url: request.url)
        }

        let result = await api.sendPushPermissionResult(
            sessionID: "session-id",
            token: token,
            permission: true
        )

        let response = try result.get()
        XCTAssertEqual(response.sessionId, "registered-session")
        XCTAssertEqual(http.sentRequests.count, 1)
    }

    // MARK: - Callback bridge

    func testSendPushPermissionCallbackDeliversResponse() {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let callback = expectation(description: "callback")

        http.sendResponder = { request in
            .json(#"{"session_id":"cb-session"}"#, url: request.url)
        }

        api.sendPushPermission(
            sessionID: "session-id",
            token: token,
            permission: true
        ) { response in
            XCTAssertEqual(response?.sessionId, "cb-session")
            callback.fulfill()
        }

        wait(for: [callback], timeout: 1)
    }

    // MARK: - Failure categories

    func testSendPushPermissionResultReturnsServerFailureOn400() async {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)

        http.sendResponder = { request in
            .json(#"{"error":"bad token"}"#, statusCode: 400, url: request.url)
        }

        let result = await api.sendPushPermissionResult(
            sessionID: "session-id",
            token: token,
            permission: true
        )

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(OrttoAPIError.server(let statusCode, let message, _)):
            XCTAssertEqual(statusCode, 400)
            XCTAssertEqual(message, "bad token")
        case .failure(let error):
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testSendPushPermissionCallbackReturnsNilOnFailure() {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let callback = expectation(description: "callback")

        http.sendResponder = { request in
            .json(#"{"error":"bad token"}"#, statusCode: 400, url: request.url)
        }

        api.sendPushPermission(
            sessionID: "session-id",
            token: token,
            permission: true
        ) { response in
            XCTAssertNil(response)
            callback.fulfill()
        }

        wait(for: [callback], timeout: 1)
    }

    func testSendPushPermissionResultReturnsRequestErrorOnNetworkFailure() async {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)

        http.sendResponder = { _ in
            throw OrttoHTTPError.network(URLError(.timedOut))
        }

        let result = await api.sendPushPermissionResult(
            sessionID: nil,
            token: token,
            permission: true
        )

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(OrttoAPIError.request(.network(let urlError))):
            XCTAssertEqual(urlError.code, .timedOut)
        case .failure(let error):
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
