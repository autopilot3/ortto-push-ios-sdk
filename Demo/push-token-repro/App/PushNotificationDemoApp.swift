//
//  PushNotificationDemoApp.swift
//  Ortto iOS SDK Push Demo
//
//  App entry point: initializes the Ortto SDK and shows RootView.
//

import OrttoSDKCore
import SwiftUI

@main
struct PushNotificationDemoApp: App {
    // `AppDelegate` is intentionally target-specific. Xcode compiles
    // APNSAppDelegate.swift into the APNS scheme and FCMAppDelegate.swift into
    // the FCM scheme, so this single SwiftUI entry point binds to the selected
    // target's concrete delegate.
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    init() {
        Ortto.shared.setLogger(customLogger: appLog)

        guard AppConfiguration.canInitializeSDK else {
            appLog.appError("Ortto SDK not initialized: \(AppConfiguration.orttoConfigurationFailureDetail)")
            return
        }

        Ortto.initialize(
            appKey: AppConfiguration.appKey,
            endpoint: AppConfiguration.endpoint
        ) { _ in
            appLog.sdkLifecycleInfo("Ortto.initialize completed endpoint=\(AppConfiguration.endpoint)")
        }
    }

    var body: some Scene {
        WindowGroup { RootView() }
    }
}
