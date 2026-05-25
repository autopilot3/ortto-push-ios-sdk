//
//  OrttoHTTPClient.swift
//
//  Created on 25/5/2026.
//

import Foundation

public protocol OrttoHTTPClient: AnyObject {
    func send(_ request: URLRequest) async throws -> OrttoHTTPResponse
    func downloadFile(from url: URL, kind: OrttoDownloadKind) async throws -> OrttoDownloadedFile
}

public struct OrttoHTTPResponse {
    public let data: Data
    public let response: HTTPURLResponse

    public var statusCode: Int {
        response.statusCode
    }

    public func validated() throws -> OrttoHTTPResponse {
        guard (200 ... 299).contains(statusCode) else {
            throw OrttoHTTPError.unsuccessfulStatusCode(statusCode: statusCode, data: data)
        }

        return self
    }

    public func decoded<T: Decodable>(as type: T.Type, decoder: JSONDecoder = JSONDecoder()) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw OrttoHTTPError.decoding(error.localizedDescription)
        }
    }

    public func string(encoding: String.Encoding = .utf8) -> String? {
        String(data: data, encoding: encoding)
    }
}

public struct OrttoDownloadedFile {
    public let url: URL
    public let response: HTTPURLResponse

    public init(url: URL, response: HTTPURLResponse) {
        self.url = url
        self.response = response
    }
}

public enum OrttoDownloadKind: Sendable {
    case notificationImage

    var directoryName: String {
        switch self {
        case .notificationImage:
            return "notification_images"
        }
    }
}

public enum OrttoHTTPError: Error {
    case invalidRequest(String)
    case noResponse
    case unsuccessfulStatusCode(statusCode: Int, data: Data?)
    case network(URLError)
    case decoding(String)
    case encoding(String)
    case cancelled
    case underlying(String)
}

extension OrttoHTTPError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .invalidRequest(message):
            return "Invalid request: \(message)"
        case .noResponse:
            return "No HTTP response was received."
        case let .unsuccessfulStatusCode(statusCode, data):
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            return "HTTP request failed with status \(statusCode). \(body)"
        case let .network(error):
            return error.localizedDescription
        case let .decoding(message):
            return "Failed to decode HTTP response: \(message)"
        case let .encoding(message):
            return "Failed to encode HTTP request: \(message)"
        case .cancelled:
            return "HTTP request was cancelled."
        case let .underlying(message):
            return message
        }
    }
}
