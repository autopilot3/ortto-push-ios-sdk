//
//  OrttoAPI.swift
//  SDK-level test utilities: fake responses, request recording, future pooling hooks.
//
//  Created on 25/5/2026.
//

import Foundation

// MARK: - OrttoMockResponse

/// A canned response returned by the fake API manager during tests.
public struct OrttoMockResponse {
    let data: Data
    let statusCode: Int

    /// A successful JSON response.
    public static func make(body: String = "", status: Int = 200) -> OrttoMockResponse {
        OrttoMockResponse(data: Data(body.utf8), statusCode: status)
    }

    /// A server error response. Produces `{"error":"<message>"}` when a message is given.
    public static func error(status: Int, message: String? = nil) -> OrttoMockResponse {
        let body = message.map { #"{"error":"\#($0)"}"# } ?? ""
        return OrttoMockResponse(data: Data(body.utf8), statusCode: status)
    }
}

// MARK: - OrttoFakeRegistration

/// Associates a request type with a canned response.
/// Build one with the static factories or the `=>` operator:
///
/// ```swift
/// OrttoAPI.fake([
///     FetchWidgetsRequest.self => .make(body: #"{"widgets":[]}"#),
///     RegisterIdentityRequest.self => .error(status: 403, message: "forbidden"),
/// ])
/// ```
public struct OrttoFakeRegistration {
    let requestTypeID: ObjectIdentifier
    // Closure captures R and returns R.Response as Any; the cast back is safe
    // because it was registered for this exact R.self.
    let handle: (any OrttoAPIRequest) throws -> Any

    /// Build a registration for `requestType` that always returns `mock`.
    public static func on<R: OrttoAPIRequest>(
        _ requestType: R.Type,
        returning mock: OrttoMockResponse
    ) -> OrttoFakeRegistration {
        OrttoFakeRegistration(requestTypeID: ObjectIdentifier(R.self)) { request in
            // Mirror what OrttoAPIConnector does: validate status, then decode.
            let httpResponse = OrttoHTTPResponse(
                data: mock.data,
                response: HTTPURLResponse(
                    url: URL(string: "https://ortto.fake")!,
                    statusCode: mock.statusCode,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/json"]
                )!
            )
            guard (200 ... 299).contains(mock.statusCode) else {
                throw OrttoAPIError.from(
                    OrttoHTTPError.unsuccessfulStatusCode(statusCode: mock.statusCode, data: mock.data)
                )
            }
            return try (request as! R).decodeResponse(httpResponse)
        }
    }
}

// MARK: - => operator

/// Shorthand for `OrttoFakeRegistration.on(_:returning:)`.
///
/// ```swift
/// FetchWidgetsRequest.self => .make(body: #"{"widgets":[]}"#)
/// ```
infix operator =>: AssignmentPrecedence

public func => <R: OrttoAPIRequest>(lhs: R.Type, rhs: OrttoMockResponse) -> OrttoFakeRegistration {
    .on(lhs, returning: rhs)
}

// MARK: - OrttoAPI

/// SDK-level utilities for testing and future concurrency features.
///
/// ## Faking in tests
///
/// Install fake responses in `setUp()` and clear them in `tearDown()`:
///
/// ```swift
/// override func setUp() {
///     super.setUp()
///     OrttoAPI.fake([
///         FetchWidgetsRequest.self  => .make(body: #"{"widgets":[]}"#),
///         RegisterIdentityRequest.self => .make(body: #"{"session_id":"test-123"}"#),
///     ])
/// }
///
/// override func tearDown() {
///     OrttoAPI.clearFakes()
///     super.tearDown()
/// }
///
/// func testWidgetsAreEmpty() async throws {
///     let response = try await FetchWidgetsRequest(body: body).send()
///     XCTAssertTrue(response.widgets.isEmpty)
/// }
/// ```
///
/// Any request type with no registered fake throws a clear error rather than
/// silently hitting the network, so missing registrations are caught immediately.
public enum OrttoAPI {

    /// Replace the shared API manager with one that returns fakes for registered request types.
    /// Any request type not in the list throws `OrttoHTTPError.invalidRequest` with a clear message.
    public static func fake(_ registrations: [OrttoFakeRegistration]) {
        Ortto.shared.apiManager = FakeApiManager(registrations)
    }

    /// Restore the API manager to its default uninitialised state.
    /// Call in `tearDown()` after every `fake()` call.
    public static func clearFakes() {
        Ortto.shared.apiManager = ApiManager()
    }
}
