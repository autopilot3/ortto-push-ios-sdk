//
//  FCMAppDelegate.swift
//  Ortto iOS SDK Push Demo
//
//  FCM target entry point. Firebase needs the APNS token before it can mint an
//  FCM registration token; both arrive through these delegate callbacks and the
//  FCM token is forwarded straight to the SDK.
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

        guard AppConfiguration.hasFirebaseServiceInfo else {
            appLog.appError("Firebase configuration failed: \(AppConfiguration.firebaseServiceInfoFailureDetail)")
            return true
        }

        FirebaseApp.configure()
        Messaging.messaging().delegate = self
        appLog.appInfo("FirebaseApp configured from \(AppConfiguration.firebaseServiceInfoName).plist")
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Firebase mints the FCM token once it has the APNS token.
        guard FirebaseApp.app() != nil else { return }
        Messaging.messaging().apnsToken = deviceToken
        appLog.appInfo("APNS token attached to Firebase Messaging")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        appLog.appWarn("APNS registration failed: \(error.localizedDescription)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.isEmpty else { return }
        appLog.appInfo("Firebase registration token received \(fcmToken)")

        // Ortto SDK: forward the FCM registration token.
        PushMessaging.shared.messaging(messaging, didReceiveRegistrationToken: fcmToken)
    }
}
