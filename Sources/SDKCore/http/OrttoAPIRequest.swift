//
//  OrttoAPIRequest.swift
//  Protocol for typed API requests. Each endpoint is a struct that conforms to
//  this protocol — the connector handles auth, headers, URL building, and error
//  wrapping so call sites stay clean.
//
//  Created on 25/5/2026.
//

import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
}

/// Describes one Ortto API call. Conform a struct to this protocol for each
/// endpoint; the connector handles the rest.
///
/// ```swift
/// struct RegisterIdentityRequest: OrttoAPIRequest {
///     typealias Response = IdentityRegistrationResponse
///     var method: HTTPMethod { .post }
///     var endpoint: String { "/-/events/push-mobile-session" }
///     func encodeBody(using encoder: JSONEncoder) throws -> Data? {
///         try encoder.encode(payload)
///     }
/// }
/// ```
public protocol OrttoAPIRequest<Response> {
    /// The decoded response type. Must be `Decodable`.
    associatedtype Response: Decodable

    /// HTTP method for this request.
    var method: HTTPMethod { get }

    /// Path appended to the connector's `baseURL`, e.g. `"/-/events/push-permission"`.
    /// Ignored when `absoluteURL` is non-nil.
    var endpoint: String { get }

    /// A fully-formed URL that overrides `baseURL + endpoint` construction.
    /// Use this for requests whose URL is supplied externally (e.g. tracking URLs
    /// embedded in push payloads) rather than derived from the connector's base.
    var absoluteURL: URL? { get }

    /// Whether the connector should append device identity query items to the request URL.
    /// Driven by `SendsDeviceContext` conformance — do not implement this directly.
    var appendsDeviceQueryItems: Bool { get }

    /// Retry on transient network failure? Default `false`; session-establishing requests opt in.
    var isRetryable: Bool { get }

    /// Reads/writes the session → serialized + session middleware. Default `false`; conform to `OrttoAPISessionRequest` rather than setting this.
    var isSessionBound: Bool { get }

    /// Returns a copy carrying the live `session`, injected by the middleware at send time. Default `self`.
    func injectingSession(_ session: String?) -> Self

    /// Session to persist from a successful response; `nil` leaves the stored session unchanged. Default `nil`.
    func persistedSession(from response: Response) -> String?

    /// User to persist on success (same in-lane turn as the session, so the pair stays consistent); `nil` leaves it unchanged. Default `nil`.
    func persistedUser(from response: Response) -> UserIdentifier?

    /// Return the JSON-encoded body data, or `nil` for requests with no body (e.g. GET).
    /// The connector sets `Content-Type: application/json` automatically when this is non-nil.
    func encodeBody(using encoder: JSONEncoder) throws -> Data?

    /// Decode the validated HTTP response into `Response`.
    /// Override when you need a custom `JSONDecoder` (e.g. a non-standard date strategy).
    /// The default implementation calls `response.decoded(as: Response.self)`.
    func decodeResponse(_ response: OrttoHTTPResponse) throws -> Response
}

public extension OrttoAPIRequest where Response: Decodable {
    /// Default: use `baseURL + endpoint`.
    var absoluteURL: URL? { nil }

    /// Default: do not append device identity query items.
    /// Conforming to `SendsDeviceContext` overrides this to `true`.
    var appendsDeviceQueryItems: Bool { false }

    /// Default: not retried.
    var isRetryable: Bool { false }

    /// Default: stateless w.r.t. the session (not queued, no session middleware).
    var isSessionBound: Bool { false }

    /// Default: request doesn't carry the session — unchanged.
    func injectingSession(_: String?) -> Self { self }

    /// Default: request doesn't establish a session.
    func persistedSession(from _: Response) -> String? { nil }

    /// Default: request doesn't carry an identified user.
    func persistedUser(from _: Response) -> UserIdentifier? { nil }

    /// Default: no body.
    func encodeBody(using encoder: JSONEncoder) throws -> Data? { nil }

    /// Default: standard `JSONDecoder`.
    func decodeResponse(_ response: OrttoHTTPResponse) throws -> Response {
        try response.decoded(as: Response.self)
    }

    /// Sends this request through the shared Ortto API manager.
    ///
    /// The request doesn't need to know which connector is in use — it just
    /// asks the manager, which was wired up by `Ortto.initialize()`.
    ///
    /// ```swift
    /// let widgets = try await FetchWidgetsRequest(body: body).send()
    /// let session = try await RegisterIdentityRequest(...).send()
    /// ```
    func send() async throws -> Response {
        try await Ortto.shared.apiManager.send(self)
    }
}

// MARK: - SendsDeviceContext

/// Marker protocol for requests that should have device identity query items appended
/// to their URL by the connector. Conforming requests receive platform, SDK version,
/// and other device context params that the Ortto backend uses for tracking.
///
/// Requests that simulate a web/browser context (e.g. `FetchWidgetsRequest`) should
/// NOT conform — the backend does not expect device params on those endpoints.
///
/// ```swift
/// struct RegisterIdentityRequest: OrttoAPIRequest, SendsDeviceContext { ... }
/// struct SendPushPermissionRequest: OrttoAPIRequest, SendsDeviceContext { ... }
/// ```
public protocol SendsDeviceContext: OrttoAPIRequest {}

public extension SendsDeviceContext {
    var appendsDeviceQueryItems: Bool { true }
}

// MARK: - OrttoAPISessionRequest

/// A request whose body carries the session. The middleware injects the live value into `sessionID`; conformers just declare the stored property (+ `persistedSession`).
public protocol OrttoAPISessionRequest: OrttoAPIRequest {
    /// Session carried in the body; the middleware overwrites it with the live value at send time.
    var sessionID: String? { get set }
}

public extension OrttoAPISessionRequest {
    var isSessionBound: Bool { true }

    /// Shared injection — copy the request with the live session. No per-request override.
    func injectingSession(_ session: String?) -> Self {
        var copy = self
        copy.sessionID = session
        return copy
    }
}
