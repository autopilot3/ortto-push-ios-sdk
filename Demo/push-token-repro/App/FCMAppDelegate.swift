//
//  FCMAppDelegate.swift
//  Ortto iOS SDK Push Demo
//
//  FCM target entry point. Firebase needs the APNS token before it can mint
//  an FCM registration token; both arrive through these delegate callbacks
//  and the FCM token is forwarded straight to the SDK.
//

import FirebaseCore
import FirebaseMessaging
import Foundation
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
        appLog.appInfo("launch provider=fcm target=FCM app target")

        if AppConfiguration.hasFirebaseServiceInfo {
            configureFirebaseIfNeeded()
            Messaging.messaging().delegate = self
            appLog.appInfo("Firebase Messaging delegate installed; registration tokens are forwarded from messaging(_:didReceiveRegistrationToken:)")
        } else {
            appLog.appError("Firebase configuration failed: \(AppConfiguration.firebaseServiceInfoFailureDetail)")
        }

        if let remoteNotification = launchOptions?[.remoteNotification] {
            appLog.appInfo("launched from remote notification payload=\(remoteNotification)")
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = DiagnosticsState.recordAPNSDeviceToken(deviceToken)
        print("APNS device token: \(hex)")
        appLog.appInfo("APNS device token received \(hex)")

        guard AppConfiguration.hasFirebaseServiceInfo else {
            appLog.appError("Firebase configuration failed: \(AppConfiguration.firebaseServiceInfoFailureDetail)")
            return
        }

        configureFirebaseIfNeeded()
        Messaging.messaging().delegate = self
        Messaging.messaging().apnsToken = deviceToken
        appLog.appInfo("APNS token attached to Firebase Messaging")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNS register failed: \(error.localizedDescription)")
        appLog.appWarn("FCM APNS token callback failed before Firebase Messaging could issue a token: \(error.localizedDescription)")
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken, !fcmToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            appLog.appWarn("Firebase registration token empty for delegate callback")
            return
        }

        appLog.appInfo("Firebase registration token received \(fcmToken); forwarding to Ortto PushMessaging FCM delegate adapter")
        PushMessaging.shared.messaging(messaging, didReceiveRegistrationToken: fcmToken)
    }

    private func configureFirebaseIfNeeded() {
        guard FirebaseApp.app() == nil else { return }
        FirebaseApp.configure()
        appLog.appInfo("FirebaseApp configured from \(AppConfiguration.firebaseServiceInfoName).plist")
    }
}
