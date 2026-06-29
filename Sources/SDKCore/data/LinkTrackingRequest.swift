//
//  LinkTrackingRequest.swift
//  Typed descriptor for a link-click tracking GET.
//

import Foundation

/// GET to a fully-formed tracking URL (`absoluteURL`; caller appended device params). Stateless: not session-bound, not retried.
struct LinkTrackingRequest: OrttoAPIRequest {
    typealias Response = VoidResponse

    let trackingURL: URL

    var method: HTTPMethod { .get }
    var endpoint: String { "" }            // unused — absoluteURL takes precedence
    var absoluteURL: URL? { trackingURL }

    func decodeResponse(_ response: OrttoHTTPResponse) throws -> VoidResponse {
        VoidResponse()                     // response body is not meaningful for tracking
    }
}
