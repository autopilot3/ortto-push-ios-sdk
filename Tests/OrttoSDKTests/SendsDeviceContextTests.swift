//
//  SendsDeviceContextTests.swift
//
//  Verifies that the connector appends device identity query items for requests that
//  conform to SendsDeviceContext, and omits them for requests that do not.
//
//  Created on 25/5/2026.
//

import Foundation
@testable import OrttoInAppNotifications
@testable import OrttoPushMessaging
@testable import OrttoSDKCore
import XCTest

// MARK: - Fixture request types

private struct WithDeviceContextRequest: OrttoAPIRequest, SendsDeviceContext {
    typealias Response = VoidResponse
    var method: HTTPMethod { .get }
    var endpoint: String { "/with-device" }
}

private struct WithoutDeviceContextRequest: OrttoAPIRequest {
    typealias Response = VoidResponse
    var method: HTTPMethod { .get }
    var endpoint: String { "/without-device" }
}

// MARK: - Tests

final class SendsDeviceContextTests: OrttoTestCase {

    private let baseURL = URL(string: "https://api.test")!

    private func makeConnector(http: MockOrttoHTTPClient) -> OrttoAPIConnector {
        OrttoAPIConnector(http: http, appKey: "app-key", baseURL: baseURL)
    }

    // MARK: - Protocol conformance

    func testSendsDeviceContextDefaultIsFalse() {
        XCTAssertFalse(WithoutDeviceContextRequest().appendsDeviceQueryItems)
    }

    func testSendsDeviceContextTrueWhenConforming() {
        XCTAssertTrue(WithDeviceContextRequest().appendsDeviceQueryItems)
    }

    // MARK: - Connector behaviour

    func testConnectorAppendsQueryItemsForDeviceContextRequest() async throws {
        let http = MockOrttoHTTPClient()
        http.sendResponder = { request in
            .json("{}", url: request.url)
        }

        _ = try? await makeConnector(http: http).send(WithDeviceContextRequest())

        let url = try XCTUnwrap(http.sentRequests.first?.url)
        XCTAssertNotNil(url.query, "Device identity query items should be present")
    }

    func testConnectorOmitsQueryItemsForNonDeviceContextRequest() async throws {
        let http = MockOrttoHTTPClient()
        http.sendResponder = { request in
            .json("{}", url: request.url)
        }

        _ = try? await makeConnector(http: http).send(WithoutDeviceContextRequest())

        let url = try XCTUnwrap(http.sentRequests.first?.url)
        XCTAssertNil(url.query, "Device identity query items should be absent")
    }

    // MARK: - Real request conformance

    func testRegisterIdentityRequestSendsDeviceContext() {
        let request = RegisterIdentityRequest(
            user: UserIdentifier(contactID: nil, email: "test@example.com", phone: nil, externalID: nil, firstName: nil, lastName: nil, acceptsGDPR: false),
            appKey: "key",
            shouldSkipNonExistingContacts: false
        )
        XCTAssertTrue(request.appendsDeviceQueryItems)
    }

    func testSendPushPermissionRequestSendsDeviceContext() {
        let request = SendPushPermissionRequest(
            appKey: "key",
            token: PushToken(value: "token", type: "apns"),
            permission: true
        )
        XCTAssertTrue(request.appendsDeviceQueryItems)
    }

    func testTrackDeliveryRequestSendsDeviceContext() {
        let request = TrackDeliveryRequest(trackingURL: URL(string: "https://track.test")!)
        XCTAssertTrue(request.appendsDeviceQueryItems)
    }

    func testFetchWidgetsRequestDoesNotSendDeviceContext() {
        let request = FetchWidgetsRequest(applicationKey: "key")
        XCTAssertFalse(request.appendsDeviceQueryItems)
    }
}
