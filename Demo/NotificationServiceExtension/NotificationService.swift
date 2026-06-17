//
//  NotificationService.swift
//  Ortto iOS SDK Push Demo
//
//  Notification service extension for the Ortto iOS SDK demo app.
//  Logs and validates rich push delivery while the extension is running.
//  Connect the device to a Mac and filter Console.app by this process or by
//  the subsystem below.
//

import UserNotifications
import OrttoPushMessaging
import os

private let log = Logger(subsystem: "io.ortto.push-notification-demo", category: "NSE")

final class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    private var didComplete = false
    private var fallbackTask: DispatchWorkItem?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        log.info("didReceive entered")
        log.info("raw userInfo: \(String(describing: request.content.userInfo), privacy: .public)")
        log.info("original title: '\(request.content.title, privacy: .public)' body: '\(request.content.body, privacy: .public)'")

        self.contentHandler = contentHandler
        self.bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        let wrappedHandler: (UNNotificationContent) -> Void = { content in
            log.info("contentHandler invoked: title='\(content.title, privacy: .public)' body='\(content.body, privacy: .public)' attachments=\(content.attachments.count)")
            self.complete(with: self.mergingOriginalUserInfo(from: request.content, into: content))
        }

        scheduleFallback(for: request.content)

        // Rich-push interception lives in the shared push package. APNS and FCM
        // only change how the app registers its token; the NSE receives the
        // same UNNotificationRequest either way.
        log.info("calling MessagingService.shared.didReceive")
        let handled = MessagingService.shared.didReceive(request, withContentHandler: wrappedHandler)
        log.info("MessagingService.shared.didReceive returned handled=\(handled)")

        if !handled {
            log.warning("SDK returned false; invoking contentHandler with original content as fallback")
            complete(with: request.content)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        log.error("serviceExtensionTimeWillExpire: SDK did not call contentHandler before expiration")
        fallbackTask?.cancel()
        MessagingService.shared.serviceExtensionTimeWillExpire()
        if let bestAttemptContent {
            complete(with: bestAttemptContent)
        }
    }

    private func scheduleFallback(for originalContent: UNNotificationContent) {
        fallbackTask?.cancel()
        let task = DispatchWorkItem { [weak self] in
            guard let self, !self.didComplete else { return }
            log.warning("SDK did not invoke contentHandler quickly; displaying original notification content")
            self.complete(with: originalContent)
        }
        fallbackTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 12.0, execute: task)
    }

    private func complete(with content: UNNotificationContent) {
        guard !didComplete else {
            log.warning("contentHandler already invoked; ignoring duplicate completion")
            return
        }
        didComplete = true
        fallbackTask?.cancel()
        contentHandler?(content)
        contentHandler = nil
    }

    private func mergingOriginalUserInfo(
        from originalContent: UNNotificationContent,
        into content: UNNotificationContent
    ) -> UNNotificationContent {
        guard let mutableContent = content.mutableCopy() as? UNMutableNotificationContent else {
            return content
        }

        var mergedUserInfo = originalContent.userInfo
        for (key, value) in content.userInfo {
            mergedUserInfo[key] = value
        }
        mutableContent.userInfo = mergedUserInfo
        return mutableContent
    }
}
