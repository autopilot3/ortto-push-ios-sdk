//
//  OrttoHTTPRequest.swift
//
//  Created on 25/5/2026.
//

import Foundation

public enum OrttoHTTPHeader {
    public static let acceptJSON = "application/json"
    public static let contentTypeJSON = "application/json"
    public static let userAgent = "OrttoSDK/\(version)"
}

public enum OrttoHTTPRequest {
    public static func get(url: URL, headers: [String: String] = [:]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        apply(headers: headers, to: &request)
        return request
    }

    public static func postJSON<T: Encodable>(
        url: URL,
        body: T,
        headers: [String: String] = [:],
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(OrttoHTTPHeader.contentTypeJSON, forHTTPHeaderField: "Content-Type")
        request.setValue(OrttoHTTPHeader.acceptJSON, forHTTPHeaderField: "Accept")
        apply(headers: headers, to: &request)

        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw OrttoHTTPError.encoding(error.localizedDescription)
        }

        return request
    }

    private static func apply(headers: [String: String], to request: inout URLRequest) {
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
    }
}

public extension URLComponents {
    mutating func appendQueryItems(_ newQueryItems: [URLQueryItem]) {
        queryItems = (queryItems ?? []) + newQueryItems
    }
}
