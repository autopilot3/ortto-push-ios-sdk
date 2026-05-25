//
//  OrttoAPIFakeTests.swift
//
//  Created on 25/5/2026.
//

import Foundation
@testable import OrttoSDKCore
import XCTest

// MARK: - Fixture request types

private struct PingRequest: OrttoAPIRequest {
    typealias Response = PingResponse
    var method: HTTPMethod { .get }
    var endpoint: String { "/ping" }
}

private struct EchoRequest: OrttoAPIRequest {
    typealias Response = EchoResponse
    let value: String
    var method: HTTPMethod { .post }
    var endpoint: String { "/echo" }
    func encodeBody(using encoder: JSONEncoder) throws -> Data? {
        try encoder.encode(["value": value])
    }
}

private struct PingResponse: Decodable { let ok: Bool }
private struct EchoResponse: Decodable { let value: String }

// MARK: - Tests

final class OrttoAPIFakeTests: OrttoTestCase {

    override func tearDown() {
        OrttoAPI.clearFakes()
        super.tearDown()
    }

    // MARK: - Basic interception

    func testFakeInterceptsRequestAndReturnsDecodedResponse() async throws {
        OrttoAPI.fake([
            PingRequest.self => .make(body: #"{"ok":true}"#),
        ])

        let response = try await PingRequest().send()

        XCTAssertTrue(response.ok)
    }

    func testFakeInterceptsMultipleRequestTypes() async throws {
        OrttoAPI.fake([
            PingRequest.self  => .make(body: #"{"ok":true}"#),
            EchoRequest.self  => .make(body: #"{"value":"hello"}"#),
        ])

        let ping = try await PingRequest().send()
        let echo = try await EchoRequest(value: "hello").send()

        XCTAssertTrue(ping.ok)
        XCTAssertEqual(echo.value, "hello")
    }

    // MARK: - Error faking

    func testFakeThrowsServerErrorForNon2xxStatus() async throws {
        OrttoAPI.fake([
            PingRequest.self => .error(status: 503, message: "service unavailable"),
        ])

        do {
            _ = try await PingRequest().send()
            XCTFail("Expected OrttoAPIError.server")
        } catch OrttoAPIError.server(let statusCode, let message, _) {
            XCTAssertEqual(statusCode, 503)
            XCTAssertEqual(message, "service unavailable")
        }
    }

    func testFakeThrowsServerErrorWithNilMessageWhenNoBody() async throws {
        OrttoAPI.fake([
            PingRequest.self => .error(status: 500),
        ])

        do {
            _ = try await PingRequest().send()
            XCTFail("Expected OrttoAPIError.server")
        } catch OrttoAPIError.server(let statusCode, let message, _) {
            XCTAssertEqual(statusCode, 500)
            XCTAssertNil(message)
        }
    }

    // MARK: - Missing registration

    func testFakeThrowsInvalidRequestWhenNoRegistrationFound() async throws {
        OrttoAPI.fake([
            // PingRequest not registered — EchoRequest is
            EchoRequest.self => .make(body: #"{"value":"x"}"#),
        ])

        do {
            _ = try await PingRequest().send()
            XCTFail("Expected OrttoHTTPError.invalidRequest")
        } catch OrttoHTTPError.invalidRequest(let message) {
            XCTAssertTrue(message.contains("PingRequest"), "Error should name the missing type")
        }
    }

    // MARK: - Lifecycle

    func testClearFakesRestoresDefaultManager() async throws {
        OrttoAPI.fake([
            PingRequest.self => .make(body: #"{"ok":true}"#),
        ])

        OrttoAPI.clearFakes()

        // After clearing, send() goes to ApiManager() which has no connector —
        // it should throw invalidRequest, not return the fake.
        do {
            _ = try await PingRequest().send()
            XCTFail("Expected error after fakes cleared")
        } catch OrttoHTTPError.invalidRequest {
            // correct — no connector, not the fake
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testStaticFactoryProducesSameResultAsOperator() async throws {
        // Both syntaxes should behave identically
        let viaOperator: OrttoFakeRegistration = PingRequest.self => .make(body: #"{"ok":false}"#)
        let viaFactory: OrttoFakeRegistration = .on(PingRequest.self, returning: .make(body: #"{"ok":false}"#))

        XCTAssertEqual(viaOperator.requestTypeID, viaFactory.requestTypeID)
    }
}
