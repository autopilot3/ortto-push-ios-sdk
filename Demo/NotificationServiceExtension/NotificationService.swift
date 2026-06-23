//
//  NotificationService.swift
//  Ortto iOS SDK Push Demo
//
//  The notification service extension. The Ortto SDK does the work — it parses
//  the push payload, attaches rich media, and tracks delivery — so this file
//  stays at Apple's template shape plus two SDK calls. APNS and FCM share it
//  unchanged; only token registration differs between the two targets.
//

import UserNotifications
// MessagingService.shared is a mutable static the SDK does not yet annotate for
// Swift 6 concurrency. @preconcurrency keeps this Swift 6 target building until
// the SDK adopts strict concurrency.
@preconcurrency import OrttoPushMessaging

final class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent

        // Ortto SDK: hand the notification to the SDK. It enriches and delivers
        // Ortto pushes; for anything else it returns false, so we deliver the
        // original content unchanged.
        let handled = MessagingService.shared.didReceive(request, withContentHandler: contentHandler)
        if !handled {
            contentHandler(request.content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Ortto SDK: the system is out of time — let the SDK deliver the best
        // content it has assembled so far.
        MessagingService.shared.serviceExtensionTimeWillExpire()
        if let bestAttemptContent {
            contentHandler?(bestAttemptContent)
        }
    }
}
