//
//  MockOrttoHTTPClient.swift
//
//  Created on 25/5/2026.
//

import Foundation
@testable import OrttoSDKCore

final class MockOrttoHTTPClient: OrttoHTTPClient {
    typealias SendResponder = (URLRequest) async throws -> OrttoHTTPResponse
    typealias DownloadResponder = (URL, OrttoDownloadKind) async throws -> OrttoDownloadedFile

    private let lock = NSLock()
    private var _sentRequests: [URLRequest] = []
    private var _downloadRequests: [(url: URL, kind: OrttoDownloadKind)] = []

    var sentRequests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _sentRequests
    }

    var downloadRequests: [(url: URL, kind: OrttoDownloadKind)] {
        lock.lock()
        defer { lock.unlock() }
        return _downloadRequests
    }

    var sendResponder: SendResponder?
    var downloadResponder: DownloadResponder?

    func send(_ request: URLRequest) async throws -> OrttoHTTPResponse {
        recordSentRequest(request)

        guard let sendResponder = sendResponder else {
            throw OrttoHTTPError.invalidRequest("MockOrttoHTTPClient.sendResponder was not set")
        }

        return try await sendResponder(request)
    }

    func downloadFile(from url: URL, kind: OrttoDownloadKind) async throws -> OrttoDownloadedFile {
        recordDownloadRequest(url: url, kind: kind)

        guard let downloadResponder = downloadResponder else {
            throw OrttoHTTPError.invalidRequest("MockOrttoHTTPClient.downloadResponder was not set")
        }

        return try await downloadResponder(url, kind)
    }

    private func recordSentRequest(_ request: URLRequest) {
        lock.lock()
        _sentRequests.append(request)
        lock.unlock()
    }

    private func recordDownloadRequest(url: URL, kind: OrttoDownloadKind) {
        lock.lock()
        _downloadRequests.append((url, kind))
        lock.unlock()
    }
}

extension OrttoHTTPResponse {
    static func json(_ string: String, statusCode: Int = 200, url: URL? = nil) -> OrttoHTTPResponse {
        OrttoHTTPResponse(
            data: Data(string.utf8),
            response: HTTPURLResponse(
                url: url ?? URL(string: "https://example.test")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
        )
    }
}

extension HTTPURLResponse {
    static func ok(url: URL) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}
