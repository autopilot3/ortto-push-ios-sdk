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

        /// Returns nil when the payload has no usable image or the attachment cannot be created.
        func optionalAttachment(from imageURLString: String?) async -> UNNotificationAttachment? {
            guard let imageURLString, let imageURL = URL(string: imageURLString) else {
                return nil
            }

            do {
                return try await attachment(from: imageURL)
            } catch {
                Ortto.log().debug("NotificationAttachmentDownloader@attachment.fail \(error.localizedDescription)")
                return nil
            }
        }
    }
#endif
