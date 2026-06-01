//
//  HTTPClientTests.swift
//
//  Created on 25/5/2026.
//

import Foundation
@testable import OrttoSDKCore
import XCTest

final class HTTPClientTests: OrttoTestCase {
    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

    func testURLSessionClientSendsRequest() async throws {
        let client = makeHTTPClient()

        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/test")

            return (.ok(url: request.url!), Data(#"{"ok":true}"#.utf8))
        }

        var request = URLRequest(url: URL(string: "https://example.test/test")!)
        request.httpMethod = "POST"
        request.httpBody = Data(#"{"hello":"world"}"#.utf8)

        let response = try await client.send(request)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.string(), #"{"ok":true}"#)
    }

    func testResponseValidationThrowsForUnsuccessfulStatus() throws {
        let response = OrttoHTTPResponse.json(
            #"{"error":"bad request"}"#,
            statusCode: 400,
            url: URL(string: "https://example.test/fail")
        )

        do {
            _ = try response.validated()
            XCTFail("Expected validation to throw")
        } catch OrttoHTTPError.unsuccessfulStatusCode(let statusCode, let data) {
            XCTAssertEqual(statusCode, 400)
            XCTAssertEqual(String(data: data ?? Data(), encoding: .utf8), #"{"error":"bad request"}"#)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    private func makeHTTPClient() -> OrttoURLSessionHTTPClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return OrttoURLSessionHTTPClient(configuration: configuration)
    }
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: OrttoHTTPError.invalidRequest("URLProtocolStub.handler was not set"))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
