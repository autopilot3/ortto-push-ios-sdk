//
//  RetryPolicy.swift
//  Minimal retry: only transient network failures (never reached the server) retry; anything the server answered (incl. 4xx/5xx) does not.
//

import Foundation

/// URLError codes that mean "couldn't reach the server" — worth a quick retry.
private let retryableURLErrorCodes: Set<URLError.Code> = [
    .timedOut, .networkConnectionLost, .notConnectedToInternet,
    .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
]

/// True only for a transient network/connectivity failure (no server response).
func isTransientNetworkFailure(_ error: Error) -> Bool {
    let httpError: OrttoHTTPError?
    switch error {
    case let apiError as OrttoAPIError:
        if case let .request(inner) = apiError { httpError = inner } else { httpError = nil }
    case let raw as OrttoHTTPError:
        httpError = raw
    default:
        httpError = nil
    }
    if case let .network(urlError) = httpError {
        return retryableURLErrorCodes.contains(urlError.code)
    }
    return false
}

/// Retries `operation` on transient network failures, up to `maxAttempts` with short backoff (`<= 1` disables retry). Honors cancellation.
func withRetry<T>(maxAttempts: Int, operation: () async throws -> T) async throws -> T {
    var attempt = 1
    while true {
        do {
            return try await operation()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard attempt < maxAttempts, isTransientNetworkFailure(error) else { throw error }
            try await Task.sleep(nanoseconds: UInt64(attempt) * 300_000_000) // 0.3s, 0.6s, …
            attempt += 1
        }
    }
}
