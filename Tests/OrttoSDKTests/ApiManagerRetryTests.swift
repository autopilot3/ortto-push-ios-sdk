//
//  ApiManagerRetryTests.swift
//

import Foundation
@testable import OrttoSDKCore
import XCTest

final class ApiManagerRetryTests: OrttoTestCase {

    private let baseURL = URL(string: "https://api.example.test")!

    private func makeApiManager(http: MockOrttoHTTPClient) -> ApiManager {
        ApiManager(connector: OrttoAPIConnector(http: http, appKey: "app-key", baseURL: baseURL))
    }

    /// A transient network failure (no server response) is retried until it clears.
    func testRetriesTransientNetworkFailureThenSucceeds() async throws {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let attempts = AtomicCounter()
        http.sendResponder = { _ in
            let n = attempts.increment()
            if n < 3 { throw OrttoHTTPError.network(URLError(.timedOut)) }
            return .json(#"{"session_id":"ok"}"#)
        }

        let response = try await api.send(RetryableProbeRequest())

        XCTAssertEqual(response.sessionId, "ok")
        XCTAssertEqual(attempts.value, 3, "should retry the network failure until it clears")
    }

    /// A 4xx is a server response — never retried.
    func testClientErrorIsNotRetried() async {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let attempts = AtomicCounter()
        http.sendResponder = { _ in
            _ = attempts.increment()
            return .json(#"{"error":"bad request"}"#, statusCode: 400)
        }

        do {
            _ = try await api.send(RetryableProbeRequest())
            XCTFail("expected a thrown error")
        } catch {
            // expected
        }
        XCTAssertEqual(attempts.value, 1, "4xx must never retry")
    }

    /// A 5xx is also a server response — NOT retried (a retry would repeat the same answer).
    func testServerErrorIsNotRetried() async {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let attempts = AtomicCounter()
        http.sendResponder = { _ in
            _ = attempts.increment()
            return .json(#"{"error":"down"}"#, statusCode: 503)
        }

        do {
            _ = try await api.send(RetryableProbeRequest())
            XCTFail("expected a thrown error")
        } catch {
            // expected
        }
        XCTAssertEqual(attempts.value, 1, "the server responded (5xx) — not a network failure, so no retry")
    }

    /// Network failure caps out after the max attempts.
    func testGivesUpAfterMaxAttempts() async {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let attempts = AtomicCounter()
        http.sendResponder = { _ in
            _ = attempts.increment()
            throw OrttoHTTPError.network(URLError(.networkConnectionLost))
        }

        do {
            _ = try await api.send(RetryableProbeRequest())
            XCTFail("expected a thrown error")
        } catch {
            // expected
        }
        XCTAssertEqual(attempts.value, 3, "caps at 3 attempts")
    }

    /// A non-retryable request makes a single attempt even on a network failure.
    func testNonRetryableRequestIsNotRetried() async {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let attempts = AtomicCounter()
        http.sendResponder = { _ in
            _ = attempts.increment()
            throw OrttoHTTPError.network(URLError(.timedOut))
        }

        do {
            _ = try await api.send(NonRetryableProbeRequest())
            XCTFail("expected a thrown error")
        } catch {
            // expected
        }
        XCTAssertEqual(attempts.value, 1, "a non-retryable request makes a single attempt")
    }

    func testRetryHonorsCancellation() async {
        let http = MockOrttoHTTPClient()
        let api = makeApiManager(http: http)
        let attempts = AtomicCounter()
        http.sendResponder = { _ in
            _ = attempts.increment()
            throw OrttoHTTPError.network(URLError(.timedOut))
        }

        let task = Task { try await api.send(RetryableProbeRequest()) }
        // Let the first attempt fail and the retry enter backoff, then cancel.
        try? await Task.sleep(nanoseconds: 50_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("expected cancellation")
        } catch is CancellationError {
            // expected
        } catch {
            // A transient error is also acceptable if the race lands there first.
        }
        XCTAssertLessThanOrEqual(attempts.value, 2, "cancellation stops further retries")
    }
}

private struct ProbeResponse: Decodable {
    let sessionId: String
    enum CodingKeys: String, CodingKey { case sessionId = "session_id" }
}

private struct RetryableProbeRequest: OrttoAPIRequest {
    typealias Response = ProbeResponse
    var method: HTTPMethod { .post }
    var endpoint: String { "/-/probe" }
    var isRetryable: Bool { true }
}

private struct NonRetryableProbeRequest: OrttoAPIRequest {
    typealias Response = ProbeResponse
    var method: HTTPMethod { .post }
    var endpoint: String { "/-/probe" }
}
