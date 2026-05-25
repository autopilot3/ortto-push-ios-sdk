//
//  MessagingServiceInterceptTests.swift
//
//  Created on 25/5/2026.
//

import Foundation
@testable import OrttoPushMessaging
@testable import OrttoSDKCore
import XCTest

#if canImport(UserNotifications)
    import UserNotifications

    final class MessagingServiceInterceptTests: OrttoTestCase {

        // MARK: - Happy path

        func testDidReceiveInterceptsOrttoPushAndDeliversModifiedNotification() throws {
            let httpClient = MockOrttoHTTPClient()
            let categoryRecorder = NotificationCategoryRecorder()
            let service = MessagingService(
                httpClientFactory: { httpClient },
                categoryRegistrar: { category in await categoryRecorder.register(category) }
            )

            let imageURL = URL(string: "https://cdn.example.test/push-image.png")!
            let trackingURL = URL(string: "https://tracking.example.test/delivered?message_id=message-123")!

            httpClient.downloadResponder = { url, kind in
                XCTAssertEqual(url, imageURL)
                XCTAssertEqual(kind, .notificationImage)
                let fileURL = try PushNotificationTestFiles.writeTinyPNG()
                return OrttoDownloadedFile(url: fileURL, response: .ok(url: url))
            }

            httpClient.sendResponder = { request in
                XCTAssertEqual(request.httpMethod, "GET")
                let url = try XCTUnwrap(request.url)
                XCTAssertEqual(url.scheme, trackingURL.scheme)
                XCTAssertEqual(url.host, trackingURL.host)
                XCTAssertEqual(url.path, trackingURL.path)

                let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
                let query = Dictionary(uniqueKeysWithValues: queryItems.compactMap { item in
                    item.value.map { (item.name, $0) }
                })
                XCTAssertEqual(query["message_id"], "message-123")
                XCTAssertNotNil(query["an"])
                XCTAssertNotNil(query["av"])
                XCTAssertNotNil(query["sv"])
                XCTAssertNotNil(query["os"])
                XCTAssertNotNil(query["ov"])
                XCTAssertNotNil(query["dc"])

                return OrttoHTTPResponse(data: Data(), response: .ok(url: url))
            }

            let request = UNNotificationRequest(
                identifier: "request-123",
                content: makePushContent(imageURL: imageURL, trackingURL: trackingURL),
                trigger: nil
            )

            let contentDelivered = expectation(description: "content delivered")
            var deliveredContent: UNNotificationContent?

            let didIntercept = service.didReceive(request) { content in
                deliveredContent = content
                contentDelivered.fulfill()
            }

            XCTAssertTrue(didIntercept)
            wait(for: [contentDelivered], timeout: 5)

            let content = try XCTUnwrap(deliveredContent)
            XCTAssertEqual(content.title, "New release")
            XCTAssertEqual(content.body, "The notification service extension rewrote this body.")
            XCTAssertEqual(content.categoryIdentifier, "ortto-push-category")
            XCTAssertEqual(content.sound, .default)
            XCTAssertEqual(content.attachments.count, 1)
            XCTAssertEqual(content.attachments.first?.identifier, "image")

            let userInfo = try XCTUnwrap(content.userInfo as? [String: String])
            XCTAssertEqual(userInfo["open_release"], "ortto://release")
            XCTAssertEqual(userInfo["view_docs"], "ortto://docs")
            XCTAssertEqual(userInfo[UNNotificationDefaultActionIdentifier], "ortto://primary")

            let category = try XCTUnwrap(categoryRecorder.latestCategory)
            XCTAssertEqual(category.identifier, "ortto-push-category")
            XCTAssertEqual(category.actions.map(\.identifier), ["open_release", "view_docs"])

            XCTAssertEqual(httpClient.downloadRequests.count, 1)
            XCTAssertEqual(httpClient.sentRequests.count, 1)
        }

        // MARK: - Non-Ortto payload

        func testDidReceiveReturnsFalseWhenPayloadIsNotOrttoPush() {
            let service = MessagingService()
            let content = UNMutableNotificationContent()
            content.title = "Not Ortto"

            let request = UNNotificationRequest(identifier: "request-456", content: content, trigger: nil)

            let didIntercept = service.didReceive(request) { _ in
                XCTFail("Non-Ortto notifications should not be delivered by MessagingService")
            }

            XCTAssertFalse(didIntercept)
        }

        // MARK: - Extension expiry

        func testServiceExtensionTimeWillExpireDeliversBestAttemptContent() {
            let httpClient = MockOrttoHTTPClient()
            let service = MessagingService(
                httpClientFactory: { httpClient },
                categoryRegistrar: { _ in true }
            )

            httpClient.downloadResponder = { _, _ in
                try await Task.sleep(nanoseconds: 2_000_000_000)
                throw OrttoHTTPError.cancelled
            }

            httpClient.sendResponder = { request in
                try await Task.sleep(nanoseconds: 2_000_000_000)
                return OrttoHTTPResponse(data: Data(), response: .ok(url: request.url!))
            }

            let request = UNNotificationRequest(
                identifier: "request-expire",
                content: makePushContent(
                    imageURL: URL(string: "https://cdn.example.test/slow.png")!,
                    trackingURL: URL(string: "https://tracking.example.test/slow")!
                ),
                trigger: nil
            )

            let contentDelivered = expectation(description: "best attempt delivered")
            var deliveredContent: UNNotificationContent?

            let didIntercept = service.didReceive(request) { content in
                deliveredContent = content
                contentDelivered.fulfill()
            }

            XCTAssertTrue(didIntercept)
            service.serviceExtensionTimeWillExpire()

            wait(for: [contentDelivered], timeout: 1)

            XCTAssertEqual(deliveredContent?.title, "New release")
            XCTAssertEqual(deliveredContent?.body, "The notification service extension rewrote this body.")
            XCTAssertEqual(deliveredContent?.attachments.count, 0)
        }

        // MARK: - Download failures

        func testDidReceiveDeliversWithoutImageWhenDownloadFails() {
            let httpClient = MockOrttoHTTPClient()
            let service = MessagingService(
                httpClientFactory: { httpClient },
                categoryRegistrar: { _ in true }
            )

            httpClient.downloadResponder = { _, _ in
                throw OrttoHTTPError.network(URLError(.timedOut))
            }

            httpClient.sendResponder = { request in
                OrttoHTTPResponse(data: Data(), response: .ok(url: request.url!))
            }

            let request = UNNotificationRequest(
                identifier: "request-download-fail",
                content: makePushContent(
                    imageURL: URL(string: "https://cdn.example.test/image.png")!,
                    trackingURL: URL(string: "https://tracking.example.test/delivered")!
                ),
                trigger: nil
            )

            let contentDelivered = expectation(description: "content delivered without image")
            var deliveredContent: UNNotificationContent?

            let didIntercept = service.didReceive(request) { content in
                deliveredContent = content
                contentDelivered.fulfill()
            }

            XCTAssertTrue(didIntercept)
            wait(for: [contentDelivered], timeout: 5)

            XCTAssertEqual(deliveredContent?.title, "New release")
            XCTAssertEqual(deliveredContent?.attachments.count, 0)
            XCTAssertEqual(httpClient.downloadRequests.count, 1)
        }

        // MARK: - Tracking failures

        func testDidReceiveDeliversWhenTrackingFails() {
            let httpClient = MockOrttoHTTPClient()
            let service = MessagingService(
                httpClientFactory: { httpClient },
                categoryRegistrar: { _ in true }
            )

            httpClient.downloadResponder = { url, _ in
                let fileURL = try PushNotificationTestFiles.writeTinyPNG()
                return OrttoDownloadedFile(url: fileURL, response: .ok(url: url))
            }

            httpClient.sendResponder = { _ in
                throw OrttoHTTPError.network(URLError(.notConnectedToInternet))
            }

            let request = UNNotificationRequest(
                identifier: "request-tracking-fail",
                content: makePushContent(
                    imageURL: URL(string: "https://cdn.example.test/image.png")!,
                    trackingURL: URL(string: "https://tracking.example.test/delivered")!
                ),
                trigger: nil
            )

            let contentDelivered = expectation(description: "content delivered despite tracking failure")
            var deliveredContent: UNNotificationContent?

            let didIntercept = service.didReceive(request) { content in
                deliveredContent = content
                contentDelivered.fulfill()
            }

            XCTAssertTrue(didIntercept)
            wait(for: [contentDelivered], timeout: 5)

            XCTAssertEqual(deliveredContent?.title, "New release")
            XCTAssertEqual(deliveredContent?.attachments.count, 1)
            XCTAssertEqual(httpClient.sentRequests.count, 1)
        }

        // MARK: - Optional fields absent

        func testDidReceiveSkipsDownloadWhenNoImageURL() {
            let httpClient = MockOrttoHTTPClient()
            let service = MessagingService(
                httpClientFactory: { httpClient },
                categoryRegistrar: { _ in true }
            )

            httpClient.sendResponder = { request in
                OrttoHTTPResponse(data: Data(), response: .ok(url: request.url!))
            }

            let request = UNNotificationRequest(
                identifier: "request-no-image",
                content: makePushContent(imageURL: nil, trackingURL: URL(string: "https://tracking.example.test/delivered")!),
                trigger: nil
            )

            let contentDelivered = expectation(description: "content delivered without image fetch")
            var deliveredContent: UNNotificationContent?

            let didIntercept = service.didReceive(request) { content in
                deliveredContent = content
                contentDelivered.fulfill()
            }

            XCTAssertTrue(didIntercept)
            wait(for: [contentDelivered], timeout: 5)

            XCTAssertEqual(deliveredContent?.attachments.count, 0)
            XCTAssertEqual(httpClient.downloadRequests.count, 0)
        }

        func testDidReceiveSkipsTrackingWhenNoTrackingURL() {
            let httpClient = MockOrttoHTTPClient()
            let service = MessagingService(
                httpClientFactory: { httpClient },
                categoryRegistrar: { _ in true }
            )

            httpClient.downloadResponder = { url, _ in
                let fileURL = try PushNotificationTestFiles.writeTinyPNG()
                return OrttoDownloadedFile(url: fileURL, response: .ok(url: url))
            }

            let request = UNNotificationRequest(
                identifier: "request-no-tracking",
                content: makePushContent(imageURL: URL(string: "https://cdn.example.test/image.png")!, trackingURL: nil),
                trigger: nil
            )

            let contentDelivered = expectation(description: "content delivered without tracking call")
            var deliveredContent: UNNotificationContent?

            let didIntercept = service.didReceive(request) { content in
                deliveredContent = content
                contentDelivered.fulfill()
            }

            XCTAssertTrue(didIntercept)
            wait(for: [contentDelivered], timeout: 5)

            XCTAssertEqual(deliveredContent?.attachments.count, 1)
            XCTAssertEqual(httpClient.sentRequests.count, 0)
        }

        // MARK: - Helpers

        private func makePushContent(imageURL: URL?, trackingURL: URL?) -> UNNotificationContent {
            let content = UNMutableNotificationContent()
            content.title = "Original title"
            content.body = "Original body"
            content.categoryIdentifier = "ortto-push-category"

            var userInfo: [String: Any] = [
                "title": "New release",
                "body": "The notification service extension rewrote this body.",
                "actions": """
                    [
                        {"action":"open_release","title":"Open","link":"ortto://release"},
                        {"action":"view_docs","title":"Docs","link":"ortto://docs"}
                    ]
                    """,
                "primary_action": """
                    {"action":"primary","title":"Primary","link":"ortto://primary"}
                    """
            ]

            if let imageURL {
                userInfo["image"] = imageURL.absoluteString
            }

            userInfo["ortto_notification_id"] = "message-123"

            if let trackingURL {
                userInfo["event_tracking_url"] = trackingURL.absoluteString
            }

            content.userInfo = userInfo
            return content
        }
    }

    // MARK: - Test doubles

    private final class NotificationCategoryRecorder {
        private let lock = NSLock()
        private var categories: [UNNotificationCategory] = []

        var latestCategory: UNNotificationCategory? {
            lock.lock()
            defer { lock.unlock() }
            return categories.last
        }

        func register(_ category: UNNotificationCategory) async -> Bool {
            lock.lock()
            categories.append(category)
            lock.unlock()
            return true
        }
    }

    private enum PushNotificationTestFiles {
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
