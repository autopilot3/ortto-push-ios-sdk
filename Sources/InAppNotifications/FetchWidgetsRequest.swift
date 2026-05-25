//
//  FetchWidgetsRequest.swift
//  The request IS the body — no separate WidgetsGetRequest needed.
//
//  Created on 25/5/2026.
//

import Foundation
import OrttoSDKCore

/// Fetches the widget configuration for the current user session.
/// Endpoint: POST `/-/widgets/get`
///
/// Encodes itself as the POST body using the short wire-format keys.
/// Uses a custom date decoder because the API returns dates in
/// `"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"` form.
struct FetchWidgetsRequest: OrttoAPIRequest, Encodable {
    typealias Response = WidgetsResponse

    // MARK: - Fields (wire format)

    let sessionId: String?
    let contactId: String?
    let emailAddress: String?
    let phoneNumber: String?
    let applicationKey: String
    let talkEnabled: Bool
    let talkToken: String?
    let url: String?
    let ottlk: String

    // MARK: - Init

    init(
        sessionId: String?,
        applicationKey: String,
        contactId: String? = nil,
        emailAddress: String? = nil
    ) {
        self.sessionId = sessionId
        self.applicationKey = applicationKey
        self.contactId = contactId
        self.emailAddress = emailAddress
        phoneNumber = nil
        talkEnabled = false
        talkToken = nil
        url = nil
        ottlk = ""
    }

    // MARK: - OrttoAPIRequest

    var method: HTTPMethod { .post }
    var endpoint: String { "/-/widgets/get" }

    /// Encodes `self` — no separate body struct needed.
    func encodeBody(using encoder: JSONEncoder) throws -> Data? {
        try encoder.encode(self)
    }

    func decodeResponse(_ response: OrttoHTTPResponse) throws -> WidgetsResponse {
        let decoder = JSONDecoder()
        // Use ISO8601DateFormatter so the trailing Z is correctly interpreted
        // as UTC rather than treated as a literal character. The old DateFormatter
        // pattern quoted 'Z', which silently decoded every date in the device's
        // local timezone — causing expiry comparisons to be off by the UTC offset.
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = isoFormatter.date(from: string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO 8601 date string: \(string)"
                )
            }
            return date
        }
        return try response.decoded(as: WidgetsResponse.self, decoder: decoder)
    }

    // MARK: - Wire-format coding keys

    enum CodingKeys: String, CodingKey {
        case sessionId       = "s"
        case contactId       = "c"
        case emailAddress    = "e"
        case phoneNumber     = "p"
        case applicationKey  = "h"
        case talkEnabled     = "tk"
        case talkToken       = "tt"
        case url             = "u"
        case ottlk
    }
}
