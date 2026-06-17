//
//  APNSAppDelegate.swift
//  Ortto iOS SDK Push Demo
//
//  APNS target entry point. iOS delivers the APNS device token through these
//  AppDelegate callbacks; the token is forwarded straight to the SDK.
//

import OrttoPushMessagingAPNS
import UIKit
import UserNotifications

let appPushProvider: PushProvider = .apns

@available(iOSApplicationExtension, unavailable)
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let hex = DiagnosticsState.recordAPNSDeviceToken(deviceToken)
        appLog.appInfo("APNS device token received \(hex)")

        // Ortto SDK: forward the APNS device token — the whole APNS integration.
        PushMessaging.shared.registerDeviceToken(apnsToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        appLog.appWarn("APNS registration failed: \(error.localizedDescription)")
    }
}
