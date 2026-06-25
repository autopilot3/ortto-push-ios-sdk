//
//  NotificationAttachmentDownloader.swift
//
//  Created on 25/5/2026.
//

import Foundation
import OrttoSDKCore

#if canImport(UserNotifications)
    @preconcurrency import UserNotifications

    final class NotificationAttachmentDownloader {
        private let httpClient: OrttoHTTPClient

        init(httpClient: OrttoHTTPClient) {
            self.httpClient = httpClient
        }

        /// Downloads an image and converts the downloaded file into a notification attachment.
        func attachment(from imageURL: URL) async throws -> UNNotificationAttachment {
            let file = try await httpClient.downloadFile(from: imageURL, kind: .notificationImage)

            return try UNNotificationAttachment(
                identifier: "image",
                url: file.url,
                options: nil
            )
        }

        /// Returns nil when the payload has no usable image, the attachment cannot be created,
        /// or the download takes longer than `timeout` seconds. The timeout keeps a slow image
        /// from consuming the whole NSE budget so the notification still delivers (with its text
        /// and action buttons) before the extension expires.
        func optionalAttachment(
            from imageURLString: String?,
            timeout: TimeInterval = 20
        ) async -> UNNotificationAttachment? {
            guard let imageURLString, let imageURL = URL(string: imageURLString) else {
                return nil
            }

            do {
                return try await withThrowingTaskGroup(of: UNNotificationAttachment?.self) { group in
                    group.addTask { try await self.attachment(from: imageURL) }
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        return nil
                    }
                    // Whichever finishes first wins; cancel the loser (the download or the timer).
                    let result = try await group.next() ?? nil
                    group.cancelAll()
                    return result
                }
            } catch {
                Ortto.log().debug("NotificationAttachmentDownloader@attachment.fail \(error.localizedDescription)")
                return nil
            }
        }
    }
#endif
