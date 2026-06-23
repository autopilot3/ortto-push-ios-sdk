//
//  OrttoAPIError.swift
//  Typed API-layer errors. The connector converts raw OrttoHTTPErrors into these
//  so feature code never has to inspect status codes or parse response bodies.
//
//  Created on 25/5/2026.
//

import Foundation

/// Errors thrown by `OrttoAPIConnector.send(_:)`.
///
/// - `request`: A transport-layer problem (network failure, bad URL, cancelled).
/// - `server`: The server responded with a non-2xx status. `message` is extracted
///             from common `{"error":"…"}` / `{"message":"…"}` response bodies.
/// - `decoding`: The response body could not be decoded into the expected type.
public enum OrttoAPIError: Error {
    case request(OrttoHTTPError)
    case server(statusCode: Int, message: String?, data: Data?)
    case decoding(Error)
}

extension OrttoAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .request(let error):
            return error.localizedDescription
        case .server(let statusCode, let message, let data):
            var description = message.map { "Server error \(statusCode): \($0)." }
                ?? "Server error \(statusCode)."
            // Surface the raw response body so failures like a 404 from the wrong
            // endpoint/data-source are diagnosable from the log alone, not just
            // the parsed `{"error":…}` summary (which is often empty or generic).
            if let body = data.flatMap({ String(data: $0, encoding: .utf8) })?
                .trimmingCharacters(in: .whitespacesAndNewlines), !body.isEmpty {
                let limit = 2048
                let truncated = body.count > limit
                    ? String(body.prefix(limit)) + "… (truncated, \(body.count) bytes total)"
                    : body
                description += " Response body: \(truncated)"
            }
            return description
        case .decoding(let error):
            return "Failed to decode API response: \(error.localizedDescription)"
        }
    }
}

extension OrttoAPIError {
    /// Converts a transport error into the appropriate API error:
    ///
    /// - `unsuccessfulStatusCode` → `.server`, parsing the body for a human-readable message.
    /// - `decoding`              → `.decoding`, so callers can distinguish decode failures
    ///                             from transport failures without inspecting the inner error.
    /// - all others              → `.request`.
    static func from(_ httpError: OrttoHTTPError) -> OrttoAPIError {
        switch httpError {
        case .unsuccessfulStatusCode(let statusCode, let data):
            let message = data.flatMap(parseServerMessage(from:))
            return .server(statusCode: statusCode, message: message, data: data)
        case .decoding(let message):
            return .decoding(NSError(
                domain: "OrttoSDK.decoding",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: message]
            ))
        default:
            return .request(httpError)
        }
    }

    /// Attempts to extract a human-readable message from common API error body shapes:
    ///   `{"error":"…"}` or `{"message":"…"}`
    private static func parseServerMessage(from data: Data) -> String? {
        struct ErrorBody: Decodable {
            let error: String?
            let message: String?
        }
        guard let body = try? JSONDecoder().decode(ErrorBody.self, from: data) else {
            return nil
        }
        return body.error ?? body.message
    }
}
