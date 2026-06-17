//
//  NotificationCallbacks.swift
//  Ortto iOS SDK Push Demo
//

import UIKit
import UserNotifications

// PushMessaging comes from the push package the running target links. APNS
// and FCM share the notification-response path; the concrete package only
// changes token registration.
#if PUSH_DEMO_FCM
import OrttoPushMessagingFCM
#else
import OrttoPushMessagingAPNS
#endif

@available(iOSApplicationExtension, unavailable)
extension AppDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handles taps and action buttons after a notification is delivered.
        // Foreground presentation is handled separately in `willPresent`.
        logNotificationResponse(response)

        // Ortto SDK: link handling happens here. The SDK opens the action
        // deeplink and tracks the click when the payload contains a tracked
        // action URL.
        let handledBySDK = PushMessaging.shared.userNotificationCenter(
            center,
            didReceive: response,
            withCompletionHandler: completionHandler
        )

        if handledBySDK {
            appLog.appInfo("notification response forwarded to Ortto SDK; action deeplink and click tracking are SDK-owned")
        } else {
            appLog.appInfo("notification response not handled by Ortto SDK; no matching action deeplink was found")
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Controls display while the app is already foregrounded. The SDK click
        // tracking path starts only when the user taps an action/notification.
        logForegroundNotification(notification)
        completionHandler([.banner, .list, .sound, .badge])
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        appLog.appInfo("remote notification received in app delegate payload=\(userInfo)")
        completionHandler(.noData)
    }

    private func logNotificationResponse(_ response: UNNotificationResponse) {
        appLog.appInfo(
            [
                "notification response received",
                "action=\(response.actionIdentifier)",
                "payload=\(response.notification.request.content.userInfo)"
            ].joined(separator: " ")
        )
    }

    private func logForegroundNotification(_ notification: UNNotification) {
        let content = notification.request.content
        appLog.appInfo(
            [
                "notification will present",
                "title='\(content.title)'",
                "body='\(content.body)'",
                "payload=\(content.userInfo)"
            ].joined(separator: " ")
        )
    }
}
