//
//  APNSAppDelegate.swift
//  Ortto iOS SDK Push Demo
//
//  APNS target entry point. iOS only delivers the APNS device token through
//  these AppDelegate callbacks; the token is forwarded straight to the SDK.
//

import Foundation
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
        appLog.appInfo("launch provider=apns target=APNS app target")

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

        appLog.appInfo("calling PushMessaging.registerDeviceToken(apnsToken:)")
        PushMessaging.shared.registerDeviceToken(apnsToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("APNS register failed: \(error.localizedDescription)")
        appLog.appWarn("APNS register failed before Ortto registration: \(error.localizedDescription)")
    }
}
