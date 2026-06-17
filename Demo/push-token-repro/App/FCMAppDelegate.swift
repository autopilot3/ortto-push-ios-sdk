//
//  FCMAppDelegate.swift
//  Ortto iOS SDK Push Demo
//
//  FCM target entry point. Firebase mints the registration token once it has
//  the APNS token; the FCM token is then forwarded straight to the SDK.
//

import FirebaseCore
import FirebaseMessaging
import OrttoPushMessagingFCM
import UIKit
import UserNotifications

let appPushProvider: PushProvider = .fcm

@available(iOSApplicationExtension, unavailable)
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self

        // Firebase reads GoogleService-Info.plist. The demo also runs without
        // it — the UI surfaces the missing-config state — so configure only
        // when the file is present instead of crashing.
        if AppConfiguration.hasFirebaseServiceInfo {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Firebase needs the APNS token to mint the FCM registration token.
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        appLog.appWarn("APNS registration failed: \(error.localizedDescription)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }

        // Ortto SDK: forward the FCM registration token.
        PushMessaging.shared.messaging(messaging, didReceiveRegistrationToken: fcmToken)
    }
}
