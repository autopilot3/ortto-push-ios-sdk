//
//  MockApiManager.swift
//
//  Created by Mitchell Flindell on 20/6/2024.
//

import Foundation
@testable import OrttoSDKCore

/// In-memory `ApiManagerInterface` for tests that don't need a real HTTP layer.
///
/// Returns `VoidResponse` for void requests (e.g. link tracking); otherwise decodes a JSON body
/// into the request's `Response` — by default `{"session_id": sessionId}` (covers identity /
/// push-permission / widget responses), or whatever a test returns from `responseBody` for a
/// richer shape. Records what was sent and honours the real manager's persistence contract.
final class MockApiManager: ApiManagerInterface {

    var appKey: String? = "mock-app-key"

    /// When false, every send throws a transient network error — before persisting anything.
    var shouldSucceed = true

    /// The session id the default canned response carries (and therefore what gets persisted).
    var sessionId = "mock-session"

    /// Per-request JSON body override; return `nil` to use the `{"session_id": …}` default.
    /// Lets a test stub any response shape instead of relying on the session-id default.
    var responseBody: ((any OrttoAPIRequest) -> String?)?

    /// Invoked at the start of every send — before the success/failure decision — so a test
    /// can count attempts, including failed ones.
    var onSend: (() -> Void)?

    /// Number of sends received.
    private(set) var sentRequestCount = 0

    /// The absolute URL of the most recent request that carried one (e.g. link tracking).
    /// Left untouched by requests without an absolute URL, so it isn't clobbered to `nil`.
    private(set) var lastTrackingUrl: URL?

    func send<R: OrttoAPIRequest>(_ request: R) async throws -> R.Response {
        sentRequestCount += 1
        if let absoluteURL = request.absoluteURL {
            lastTrackingUrl = absoluteURL
        }
        onSend?()

        guard shouldSucceed else {
            throw OrttoHTTPError.network(URLError(.timedOut))
        }

        let response = try cannedResponse(for: request)
        // Honour the persistence contract the real manager has.
        persistResponseState(from: response, for: request)
        return response
    }

    private func cannedResponse<R: OrttoAPIRequest>(for request: R) throws -> R.Response {
        if let void = VoidResponse() as? R.Response {
            return void
        }
        let json = responseBody?(request) ?? #"{"session_id":"\#(sessionId)"}"#
        return try JSONDecoder().decode(R.Response.self, from: Data(json.utf8))
    }
}
