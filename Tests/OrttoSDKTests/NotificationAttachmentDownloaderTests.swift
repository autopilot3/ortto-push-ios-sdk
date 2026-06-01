//
//  NotificationAttachmentDownloaderTests.swift
//
//  Created on 25/5/2026.
//

import Foundation
@testable import OrttoPushMessaging
@testable import OrttoSDKCore
import XCTest

#if canImport(UserNotifications)
    final class NotificationAttachmentDownloaderTests: OrttoTestCase {
        func testAttachmentDownloaderRequestsNotificationImage() async throws {
            let httpClient = MockOrttoHTTPClient()
            let downloader = NotificationAttachmentDownloader(httpClient: httpClient)
            let imageURL = URL(string: "https://cdn.example.test/image.png")!

            httpClient.downloadResponder = { url, kind in
                XCTAssertEqual(url, imageURL)
                XCTAssertEqual(kind, .notificationImage)

                let fileURL = try TestFiles.writeTinyPNG()
                return OrttoDownloadedFile(url: fileURL, response: .ok(url: url))
            }

            let attachment = try await downloader.attachment(from: imageURL)

            XCTAssertEqual(attachment.identifier, "image")
            XCTAssertEqual(httpClient.downloadRequests.count, 1)
        }

        func testOptionalAttachmentReturnsNilWhenDownloadFails() async {
            let httpClient = MockOrttoHTTPClient()
            let downloader = NotificationAttachmentDownloader(httpClient: httpClient)

            httpClient.downloadResponder = { _, _ in
                throw OrttoHTTPError.network(URLError(.timedOut))
            }

            let attachment = await downloader.optionalAttachment(from: "https://cdn.example.test/image.png")

            XCTAssertNil(attachment)
            XCTAssertEqual(httpClient.downloadRequests.count, 1)
        }

        func testAttachmentDownloaderCanReuseHTTPClientForMultipleDownloads() async throws {
            let httpClient = MockOrttoHTTPClient()
            let downloader = NotificationAttachmentDownloader(httpClient: httpClient)
            let firstURL = URL(string: "https://cdn.example.test/first.png")!
            let secondURL = URL(string: "https://cdn.example.test/second.png")!

            httpClient.downloadResponder = { url, kind in
                XCTAssertEqual(kind, .notificationImage)

                let fileURL = try TestFiles.writeTinyPNG()
                return OrttoDownloadedFile(url: fileURL, response: .ok(url: url))
            }

            let firstAttachment = try await downloader.attachment(from: firstURL)
            let secondAttachment = try await downloader.attachment(from: secondURL)

            XCTAssertEqual(firstAttachment.identifier, "image")
            XCTAssertEqual(secondAttachment.identifier, "image")
            XCTAssertEqual(httpClient.downloadRequests.map(\.url), [firstURL, secondURL])
        }
    }

    private enum TestFiles {
        static func writeTinyPNG() throws -> URL {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("ortto-tests", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            let fileURL = directory.appendingPathComponent("\(UUID().uuidString).png")
            try tinyPNG.write(to: fileURL, options: .atomic)
            return fileURL
        }

        private static let tinyPNG = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="
        )!
    }
#endif
