//
//  NotificationCallbacks.swift
//  Ortto iOS SDK Push Demo
//
//  Notification response handling, shared by both targets. Only token
//  registration differs between APNS and FCM; this path is identical.
//

import UIKit
import UserNotifications

// PushMessaging comes from the push package the running target links.
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
        // Ortto SDK: hand the tapped notification to the SDK. It opens the
        // action deeplink and tracks the click for Ortto pushes; for anything
        // else it returns false and we finish the response ourselves.
        let handled = PushMessaging.shared.userNotificationCenter(
            center,
            didReceive: response,
            withCompletionHandler: completionHandler
        )
        if !handled {
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show the notification while the app is foregrounded; the SDK's
        // click-tracking path runs only when the user taps it.
        completionHandler([.banner, .list, .sound, .badge])
    }
}
