//
//  ApiManager.swift
//  Thin wrapper around OrttoAPIConnector. Each public method guards preconditions
//  (SDK initialized, user identified) then delegates to the connector for
//  URL-building, encoding, sending, and error-wrapping.
//
//  Created by Mitch Flindell on 18/11/2022.
//

import Foundation

public protocol ApiManagerInterface {
    /// The app key this manager was configured with, or `nil` if not yet initialized.
    var appKey: String? { get }

    /// Single send path: retries when `isRetryable`; routes `isSessionBound` requests through
    /// the session lane + middleware (read→inject→send→persist) so they converge on one
    /// session. Others go straight to the connector.
    func send<R: OrttoAPIRequest>(_ request: R) async throws -> R.Response

    /// Sends straight to the connector, bypassing the session lane — for use from INSIDE an already-queued operation (a nested `send` would deadlock on the lane). Retries like `send`; the caller owns session injection/persistence.
    func sendUnqueued<R: OrttoAPIRequest>(_ request: R) async throws -> R.Response
}

extension ApiManagerInterface {

    /// Default for fakes (which have no queue): identical to `send`.
    public func sendUnqueued<R: OrttoAPIRequest>(_ request: R) async throws -> R.Response {
        try await send(request)
    }

    /// Persists the user + session a request established (consistent pair); shared by real and fake managers.
    // Two keys, no await between: an off-lane reader (only the best-effort widget fetch) could see a torn pair in a sub-µs window — negligible.
    func persistResponseState<R: OrttoAPIRequest>(from response: R.Response, for request: R) {
        if let user = request.persistedUser(from: response) {
            Ortto.shared.userStorage.user = user
        }
        if let session = request.persistedSession(from: response) {
            Ortto.shared.userStorage.session = session
        }
    }
}

public class ApiManager: ApiManagerInterface {

    private let connector: OrttoAPIConnector?

    // MARK: - Init

    /// Creates an unconfigured manager. `send` calls fail gracefully until
    /// `Ortto.initialize()` replaces this with a connector-backed instance.
    public init() {
        connector = nil
    }

    /// Creates a fully configured manager backed by the given connector.
    /// Inject this in tests: `ApiManager(connector: OrttoAPIConnector(http: mock, ...))`
    public init(connector: OrttoAPIConnector) {
        self.connector = connector
    }

    // MARK: - ApiManagerInterface

    public var appKey: String? { connector?.appKey }

    public func send<R: OrttoAPIRequest>(_ request: R) async throws -> R.Response {
        guard request.isSessionBound else {
            // Stateless request: no queue, no session middleware.
            return try await sendUnqueued(request)
        }
        guard let connector else {
            throw OrttoHTTPError.invalidRequest(
                "ApiManager: SDK not initialized. Call Ortto.initialize() before making API calls."
            )
        }
        let maxAttempts = request.isRetryable ? 3 : 1
        // Session-bound: read→send→persist runs as one lane unit so a retrying request keeps its
        // FIFO slot. Cost: its backoff briefly delays queued successors — accepted, for ordering.
        return try await Ortto.shared.requestQueue.enqueue {
            try await withRetry(maxAttempts: maxAttempts) {
                let response = try await connector.send(
                    request.injectingSession(Ortto.shared.userStorage.session)
                )
                // The send completed, so the server committed — mirror it locally even if the caller
                // has since cancelled. The next session op (a later lane turn) overwrites if needed.
                self.persistResponseState(from: response, for: request)
                return response
            }
        }
    }

    public func sendUnqueued<R: OrttoAPIRequest>(_ request: R) async throws -> R.Response {
        guard let connector else {
            throw OrttoHTTPError.invalidRequest(
                "ApiManager: SDK not initialized. Call Ortto.initialize() before making API calls."
            )
        }
        return try await withRetry(maxAttempts: request.isRetryable ? 3 : 1) {
            try await connector.send(request)
        }
    }
}
