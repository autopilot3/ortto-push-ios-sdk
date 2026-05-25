//
//  OrttoURLSessionHTTPClient.swift
//
//  Created on 25/5/2026.
//

import Foundation

public final class OrttoURLSessionHTTPClient: OrttoHTTPClient {
    private let session: URLSession

    public init(configuration: URLSessionConfiguration = .orttoEphemeral) {
        session = URLSession(configuration: configuration)
    }

    public func send(_ request: URLRequest) async throws -> OrttoHTTPResponse {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OrttoHTTPError.noResponse
            }

            return OrttoHTTPResponse(data: data, response: httpResponse)
        } catch {
            throw Self.map(error)
        }
    }

    public func downloadFile(from url: URL, kind: OrttoDownloadKind) async throws -> OrttoDownloadedFile {
        do {
            let (temporaryURL, response) = try await session.download(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw OrttoHTTPError.noResponse
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw OrttoHTTPError.unsuccessfulStatusCode(statusCode: httpResponse.statusCode, data: nil)
            }

            let destinationURL = try OrttoTemporaryFiles.moveDownloadedFile(
                from: temporaryURL,
                response: response,
                originalURL: url,
                kind: kind
            )

            return OrttoDownloadedFile(url: destinationURL, response: httpResponse)
        } catch let error as OrttoHTTPError {
            throw error
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ error: Error) -> OrttoHTTPError {
        guard let urlError = error as? URLError else {
            return OrttoHTTPError.underlying(error.localizedDescription)
        }

        if urlError.code == .cancelled {
            return .cancelled
        }

        return .network(urlError)
    }
}

public extension URLSessionConfiguration {
    static var orttoEphemeral: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.allowsCellularAccess = true
        configuration.timeoutIntervalForResource = 30
        configuration.timeoutIntervalForRequest = 60
        configuration.httpAdditionalHeaders = [
            "User-Agent": OrttoHTTPHeader.userAgent,
        ]
        return configuration
    }
}
