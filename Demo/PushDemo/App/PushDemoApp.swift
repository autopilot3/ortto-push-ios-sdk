//
//  PushDemoApp.swift
//  Ortto iOS SDK Push Demo
//
//  Start here. The Ortto SDK is integrated in a handful of places — this is the
//  map. Every call is marked with an `// Ortto SDK:` comment at the call site,
//  so `grep -rn "// Ortto SDK"` jumps you to each one.
//
//    • Initialize           this file — Ortto.initialize(appKey:endpoint:)
//    • In-app notifications this file — OrttoCapture.initialize(...) + PushViewModel+Actions.swift — OrttoCapture.shared.showWidget(_:)
//    • Identify a contact   PushViewModel+Actions.swift — Ortto.shared.identify / clearIdentity
//    • Track screen views   Home/Delivery/LogView .onAppear — Ortto.shared.screen(_:)
//    • Register push token  APNSAppDelegate / FCMAppDelegate — PushMessaging.shared.registerDeviceToken / messaging(_:didReceiveRegistrationToken:)
//    • Rich push (media)    NotificationServiceExtension — MessagingService.shared.didReceive
//    • Notification taps    NotificationCallbacks.swift — PushMessaging.shared.userNotificationCenter(...)
//    • Click tracking       PushViewModel+Actions.swift — Ortto.shared.trackLinkClick(_:)
//
//  Everything else is ordinary SwiftUI. Reading those touchpoints is the
//  whole integration.
//

@preconcurrency import OrttoInAppNotifications
@preconcurrency import OrttoSDKCore
import SwiftUI

@main
struct PushDemoApp: App {
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
            appLog.info("Ortto.initialize completed endpoint=\(AppConfiguration.endpoint)")
        }

        // Ortto SDK: enable in-app notifications (widgets). Optional — skipped
        // until ORTTO_CAPTURE_JS_URL is set, so the demo stays push-only by default.
        if AppConfiguration.canInitializeCapture {
            try? OrttoCapture.initialize(
                dataSourceKey: AppConfiguration.captureDataSourceKey,
                captureJsURL: AppConfiguration.captureJsURL,
                apiHost: AppConfiguration.endpoint
            )
        }
    }

    var body: some Scene {
        WindowGroup { RootView() }
    }
}
