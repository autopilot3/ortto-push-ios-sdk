//
//  OrttoAPIConnector.swift
//  Central request dispatcher — the Laravel Http / Saloon-style layer.
//  Holds auth config, builds URLRequests, sends via OrttoHTTPClient,
//  and converts HTTP errors into typed OrttoAPIErrors.
//
//  Created on 25/5/2026.
//

import Foundation

public final class OrttoAPIConnector {

    // MARK: - Configuration

    public let http: OrttoHTTPClient
    public let appKey: String
    /// The base URL for `endpoint`-relative requests. `nil` in contexts (e.g. NSE)
    /// where only absolute-URL requests will be sent.
    public let baseURL: URL?

    private let encoder = JSONEncoder()

    // MARK: - Init

    /// Full init for SDK-initialised contexts. All endpoint requests use `baseURL + endpoint`.
    public init(http: OrttoHTTPClient, appKey: String, baseURL: URL) {
        self.http = http
        self.appKey = appKey
        self.baseURL = baseURL
    }

    /// Lightweight init for contexts without a base URL (e.g. the Notification Service Extension).
    /// Only requests that supply `absoluteURL` can be sent through this connector.
    public init(http: OrttoHTTPClient) {
        self.http = http
        self.appKey = ""
        self.baseURL = nil
    }

    // MARK: - Typed API request

    /// Sends a typed API request and returns the decoded response.
    ///
    /// - Appends device-identity query items to every request URL.
    /// - Sets `Accept: application/json` on every request.
    /// - Sets `Content-Type: application/json` when the request has a body.
    /// - Converts `OrttoHTTPError.unsuccessfulStatusCode` → `OrttoAPIError.server`,
    ///   parsing common `{"error":"…"}` / `{"message":"…"}` response bodies.
    /// - Converts decoding failures → `OrttoAPIError.decoding`.
    /// - Passes all other transport errors through as `OrttoAPIError.request`.
    public func send<R: OrttoAPIRequest>(_ request: R) async throws -> R.Response {
        let urlRequest = try buildURLRequest(for: request)
        do {
            let response = try await http.send(urlRequest).validated()
            return try request.decodeResponse(response)
        } catch let error as OrttoHTTPError {
            throw OrttoAPIError.from(error)
        } catch let error as OrttoAPIError {
            throw error
        } catch {
            throw OrttoAPIError.decoding(error)
        }
    }

    // MARK: - Raw GET (for pre-built URLs, e.g. link tracking)

    /// Fires a GET to a fully-formed URL and validates the response status.
    /// Used for tracking calls where the URL is built by the caller rather than
    /// derived from `baseURL + endpoint`.
    public func sendGet(_ url: URL) async throws {
        let urlRequest = OrttoHTTPRequest.get(url: url)
        do {
            _ = try await http.send(urlRequest).validated()
        } catch let error as OrttoHTTPError {
            throw OrttoAPIError.from(error)
        }
    }

    // MARK: - Private

    private func buildURLRequest<R: OrttoAPIRequest>(for request: R) throws -> URLRequest {
        let resolvedURL: URL
        if let absolute = request.absoluteURL {
            resolvedURL = absolute
        } else if let baseURL {
            resolvedURL = baseURL.appendingPathComponent(request.endpoint)
        } else {
            throw OrttoHTTPError.invalidRequest(
                "OrttoAPIConnector: no baseURL configured and \(R.self) provides no absoluteURL"
            )
        }

        var components = URLComponents(url: resolvedURL, resolvingAgainstBaseURL: false)!
        if request.appendsDeviceQueryItems {
            components.appendQueryItems(DeviceIdentity.getTrackingQueryItems())
        }

        guard let url = components.url else {
            throw OrttoHTTPError.invalidRequest("Could not build URL for endpoint: \(request.endpoint)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue(OrttoHTTPHeader.acceptJSON, forHTTPHeaderField: "Accept")

        if let bodyData = try request.encodeBody(using: encoder) {
            urlRequest.httpBody = bodyData
            urlRequest.setValue(OrttoHTTPHeader.contentTypeJSON, forHTTPHeaderField: "Content-Type")
        }

        return urlRequest
    }
}
