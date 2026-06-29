//
//  OrttoAPIConnectorTests.swift
//
//  Created on 25/5/2026.
//

import Foundation
@testable import OrttoSDKCore
import XCTest

// MARK: - Fixture types

private struct EchoRequest: OrttoAPIRequest {
    typealias Response = EchoResponse
    var method: HTTPMethod { .post }
    var endpoint: String { "/echo" }
    let payload: EchoPayload
    func encodeBody(using encoder: JSONEncoder) throws -> Data? {
        try encoder.encode(payload)
    }
}

private struct EchoPayload: Codable { let value: String }
private struct EchoResponse: Decodable { let value: String }

private struct GETRequest: OrttoAPIRequest, SendsDeviceContext {
    typealias Response = EchoResponse
    var method: HTTPMethod { .get }
    var endpoint: String { "/ping" }
    // encodeBody returns nil by default — no override needed
}

// MARK: - Tests

final class OrttoAPIConnectorTests: XCTestCase {

    private let baseURL = URL(string: "https://api.example.test")!

    private func makeConnector(http: MockOrttoHTTPClient) -> OrttoAPIConnector {
        OrttoAPIConnector(http: http, appKey: "test-app-key", baseURL: baseURL)
    }

    // MARK: - Request construction

    func testSendBuildsCorrectPostRequest() async throws {
        let http = MockOrttoHTTPClient()
        let connector = makeConnector(http: http)

        http.sendResponder = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/echo")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(request.httpBody)
            let payload = try JSONDecoder().decode(EchoPayload.self, from: body)
            XCTAssertEqual(payload.value, "hello")

            return .json(#"{"value":"hello"}"#, url: request.url)
        }

        let response: EchoResponse = try await connector.send(EchoRequest(payload: EchoPayload(value: "hello")))
        XCTAssertEqual(response.value, "hello")
        XCTAssertEqual(http.sentRequests.count, 1)
    }

    func testSendBuildsCorrectGetRequestWithNoBody() async throws {
        let http = MockOrttoHTTPClient()
        let connector = makeConnector(http: http)

        http.sendResponder = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.httpBody)
            XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
            return .json(#"{"value":"pong"}"#, url: request.url)
        }

        let _: EchoResponse = try await connector.send(GETRequest())
        XCTAssertEqual(http.sentRequests.count, 1)
    }

    func testSendAppendsDeviceIdentityQueryItems() async throws {
        let http = MockOrttoHTTPClient()
        let connector = makeConnector(http: http)

        http.sendResponder = { request in
            let url = try XCTUnwrap(request.url)
            let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            // DeviceIdentity appends items like "an", "av", "sv", "os", "ov", "dc"
            XCTAssertFalse(queryItems.isEmpty, "Connector must append device identity query items")
            return .json(#"{"value":"ok"}"#, url: url)
        }

        let _: EchoResponse = try await connector.send(GETRequest())
    }

    // MARK: - Error wrapping

    func testSendThrowsServerErrorOnNon2xxResponse() async throws {
        let http = MockOrttoHTTPClient()
        let connector = makeConnector(http: http)

        http.sendResponder = { request in
            .json(#"{"error":"bad token"}"#, statusCode: 400, url: request.url)
        }

        do {
            let _: EchoResponse = try await connector.send(EchoRequest(payload: EchoPayload(value: "x")))
            XCTFail("Expected OrttoAPIError.server")
        } catch OrttoAPIError.server(let statusCode, let message, _) {
            XCTAssertEqual(statusCode, 400)
            XCTAssertEqual(message, "bad token")
        }
    }

    func testSendExtractsMessageFieldFromServerErrorBody() async throws {
        let http = MockOrttoHTTPClient()
        let connector = makeConnector(http: http)

        http.sendResponder = { request in
            .json(#"{"message":"unauthorized"}"#, statusCode: 401, url: request.url)
        }

        do {
            let _: EchoResponse = try await connector.send(EchoRequest(payload: EchoPayload(value: "x")))
            XCTFail("Expected OrttoAPIError.server")
        } catch OrttoAPIError.server(let statusCode, let message, _) {
            XCTAssertEqual(statusCode, 401)
            XCTAssertEqual(message, "unauthorized")
        }
    }

    func testSendThrowsServerErrorWithNilMessageWhenBodyIsNotJSON() async throws {
        let http = MockOrttoHTTPClient()
        let connector = makeConnector(http: http)

        http.sendResponder = { request in
            OrttoHTTPResponse(
                data: Data("Internal Server Error".utf8),
                response: HTTPURLResponse(
                    url: request.url ?? URL(string: "https://example.test")!,
                    statusCode: 500,
                    httpVersion: nil,
                    headerFields: nil
                )!
            )
        }

        do {
            let _: EchoResponse = try await connector.send(EchoRequest(payload: EchoPayload(value: "x")))
            XCTFail("Expected OrttoAPIError.server")
        } catch OrttoAPIError.server(let statusCode, let message, _) {
            XCTAssertEqual(statusCode, 500)
            XCTAssertNil(message)
        }
    }

    func testSendThrowsRequestErrorOnNetworkFailure() async throws {
        let http = MockOrttoHTTPClient()
        let connector = makeConnector(http: http)

        http.sendResponder = { _ in
            throw OrttoHTTPError.network(URLError(.notConnectedToInternet))
        }

        do {
            let _: EchoResponse = try await connector.send(EchoRequest(payload: EchoPayload(value: "x")))
            XCTFail("Expected OrttoAPIError.request")
        } catch OrttoAPIError.request(let underlying) {
            if case .network(let urlError) = underlying {
                XCTAssertEqual(urlError.code, .notConnectedToInternet)
            } else {
                XCTFail("Expected OrttoHTTPError.network")
            }
        }
    }

    func testSendThrowsDecodingErrorOnBadResponseShape() async throws {
        let http = MockOrttoHTTPClient()
        let connector = makeConnector(http: http)

        http.sendResponder = { request in
            .json(#"{"unexpected":"shape"}"#, url: request.url)
        }

        do {
            // EchoResponse expects {"value":"…"} — this JSON will decode just fine
            // because "value" is missing and Swift marks it as a decoding error.
            // Use a stricter type:
            let _: StrictResponse = try await connector.send(StrictRequest())
            XCTFail("Expected OrttoAPIError.decoding")
        } catch OrttoAPIError.decoding {
            // pass
        }
    }

}

// MARK: - Helpers for decoding error test

private struct StrictRequest: OrttoAPIRequest {
    typealias Response = StrictResponse
    var method: HTTPMethod { .get }
    var endpoint: String { "/strict" }
}

private struct StrictResponse: Decodable {
    let required: String  // field not present in the test JSON — will cause decoding error
}
