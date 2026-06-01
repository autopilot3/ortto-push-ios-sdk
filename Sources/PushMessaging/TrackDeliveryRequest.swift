//
//  TrackDeliveryRequest.swift
//
//  Created on 25/5/2026.
//

import Foundation
import OrttoSDKCore

/// Records delivery of a push notification by GETting the tracking URL embedded in the payload.
///
/// The URL is supplied fully-formed by the Ortto backend — this request sets `absoluteURL`
/// so the connector uses it directly rather than constructing `baseURL + endpoint`.
/// Device identity query items are still appended by the connector as normal.
///
/// Sent through a per-notification `OrttoAPIConnector` rather than the shared SDK connector,
/// because this request runs inside the Notification Service Extension where `Ortto.initialize()`
/// has not been called.
struct TrackDeliveryRequest: OrttoAPIRequest, SendsDeviceContext {
    typealias Response = VoidResponse

    let trackingURL: URL

    var method: HTTPMethod { .get }
    var endpoint: String { "" }           // unused — absoluteURL takes precedence
    var absoluteURL: URL? { trackingURL }

    func decodeResponse(_ response: OrttoHTTPResponse) throws -> VoidResponse {
        VoidResponse()                    // response body is not meaningful for tracking
    }
}
