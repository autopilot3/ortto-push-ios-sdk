# Ortto Push Notification Demo

This iOS app is a polished Ortto SDK integration sample for validating push notification permission, token registration, and signed-in session state.

It is intended to stay aligned with Ortto's public [Push notifications SDK for iOS](https://help.ortto.com/a-254-push-notifications-sdk-for-ios) documentation.

The flow is designed for customer support and SDK validation:

- First open requests push permission before login so registration timing is visible.
- The login screen identifies the signed-in email address with Ortto.
- Home provides a support-friendly snapshot that can be copied in one tap.
- A Delivery tab shows the selected target's APNS or FCM token registration path.
- Delivery also exposes link-click tracking for Ortto push-action deeplinks.
- Log keeps SDK events, demo-app events, and session snapshots available for deeper inspection.

## APNS vs FCM

Choose the app target that matches the push package you want to demonstrate:

- `PushNotificationDemo-APNS` links `OrttoPushMessagingAPNS`.
- `PushNotificationDemo-FCM` links `OrttoPushMessagingFCM` and Firebase Messaging.

Both targets share the SwiftUI demo shell, but each target compiles its own concrete `AppDelegate` and app `Info.plist`.
The notification service extension links the shared `OrttoPushMessaging` package because rich-push interception is the same for APNS and FCM.

### APNS target

- Calls `UIApplication.shared.registerForRemoteNotifications()`.
- `APNSAppDelegate.swift` forwards the APNS device token to `PushMessaging.shared.registerDeviceToken(apnsToken:)`.
- The app records the current iOS permission and remote-notification registration status.

### FCM target

- Configures Firebase Messaging when `GoogleService-Info.plist` is bundled.
- Attaches the APNS token to Firebase so Firebase can mint the FCM registration token.
- Forwards real Firebase registration tokens through `PushMessaging.shared.messaging(_:didReceiveRegistrationToken:)`.

This keeps the install-time package choice visible while avoiding duplicate demo UI.

## Deep Links and Click Tracking

Ortto's iOS push SDK docs call out deep links and click tracking as part of the install flow. This demo now shows both paths:

- `Info.plist` declares the target's `ortto-demo-apns://` or `ortto-demo-fcm://` URL scheme so notification action deeplinks can pass `UIApplication.shared.canOpenURL`.
- The concrete app delegate forwards tapped notification actions into `PushMessaging.shared.userNotificationCenter(...)`.
- The SDK-owned response path opens the action deeplink and calls `Ortto.shared.trackLinkClick(...)` when the payload contains a tracked action URL.
- Delivery includes a "Track link click" action where you can paste the same tracked push-action deeplink and call `Ortto.shared.trackLinkClick(...)` directly.

Use a real Ortto push action deeplink that includes a `tracking_url` query item. The demo logs UTM query parameters when they are present, then leaves the actual tracking request to the SDK.

## Project Layout

The app follows the conventional iOS App / Models / Views / ViewModels structure:

```text
push-token-repro/
├── App/             App entry point and target-specific app delegates
├── Models/          Provider enum, persisted demo state, UI model types
├── Support/         Plist-backed configuration and the shared logger
├── ViewModels/      PushViewModel: demo state, SDK flows, derived status copy
├── Views/
│   ├── RootView.swift   Shell: shows Login/ or Main/ based on sign-in state
│   ├── Login/           LoginView and its artwork/sheet components
│   ├── Main/            MainTabView and its three tabs (Home, Delivery, Log)
│   └── Components/      Design system and controls shared by both
└── Configurations/  Per-target xcconfig and Info.plist files
```

- Start at `App/PushNotificationDemoApp.swift` (`@main`) — it initializes the Ortto SDK and shows `RootView`.
- SDK calls are made directly where they happen — grep for `Ortto.shared` and `PushMessaging.shared` to see every integration point. Each button action in `ViewModels/PushViewModel+Actions.swift` calls the SDK inline; nothing is wrapped or hidden behind layers.
- `App/APNSAppDelegate.swift` and `App/FCMAppDelegate.swift` hold only the iOS-mandated token callbacks, each forwarding straight to the SDK. Xcode compiles exactly one of them per target.
- `Configurations/APNS/Info.plist` and `Configurations/FCM/Info.plist` are the target configs. They intentionally stay small: Ortto app key build setting, endpoint build setting, URL scheme, and remote-notification background mode.
- `Configurations/Local.xcconfig` is ignored by git and supplies local Ortto app keys for one or both targets.
- `NotificationServiceExtension` contains the rich-push extension, which depends only on shared `OrttoPushMessaging`.

## Key Files

| File | Purpose |
| --- | --- |
| `push-token-repro/App/PushNotificationDemoApp.swift` | App entry point (`@main`) and `Ortto.initialize` call. |
| `push-token-repro/App/APNSAppDelegate.swift` | APNS target app delegate: forwards the APNS device token to `PushMessaging.shared.registerDeviceToken(apnsToken:)`. |
| `push-token-repro/App/FCMAppDelegate.swift` | FCM target app delegate: Firebase Messaging setup; forwards registration tokens to `PushMessaging.shared.messaging(_:didReceiveRegistrationToken:)`. |
| `push-token-repro/App/NotificationCallbacks.swift` | Shared notification delegate callbacks; forwards tapped notifications to `PushMessaging.shared.userNotificationCenter(...)`. |
| `push-token-repro/Models/PushProvider.swift` | APNS/FCM provider enum used by the target-specific app delegates and UI. |
| `push-token-repro/Models/AppState.swift` | UserDefaults keys, buffered diagnostics state, and log entry model. |
| `push-token-repro/Models/UIModels.swift` | UI-only tabs, action status, toast, issue, and provider display metadata. |
| `push-token-repro/Support/AppConfiguration.swift` | Typed accessor for plist-backed app configuration and Firebase plist checks. |
| `push-token-repro/Support/AppLog.swift` | Terminal-style log stream with `ortto@ios-sdk` entries from SDK callbacks and `demo@push-demo` entries from demo code. |
| `push-token-repro/ViewModels/PushViewModel.swift` | Demo state object and UI plumbing: persisted login, toasts, statuses, and the log feed. |
| `push-token-repro/ViewModels/PushViewModel+Actions.swift` | The demo's SDK flows — identify, register, redispatch, click tracking — each calling `Ortto.shared` / `PushMessaging.shared` directly. |
| `push-token-repro/ViewModels/PushViewModel+DerivedState.swift` | Derived state for registration status, validation issues, and action labels. |
| `push-token-repro/Views/RootView.swift` | App shell: switches between `LoginView` and `MainTabView`, hosts the toast overlay. |
| `push-token-repro/Views/Login/LoginView.swift` | Login screen; signing in identifies the email with the Ortto SDK. |
| `push-token-repro/Views/Login/PaperShaderBackground.swift` | WebGL mesh-gradient login backdrop ([Paper Shaders](https://github.com/paper-design/shaders) in a transparent WKWebView); falls back to the SwiftUI gradient offline. |
| `push-token-repro/Views/Main/MainTabView.swift` | Signed-in tab controller hosting the Home, Delivery, and Log tabs. |
| `push-token-repro/Views/Main/HomeView.swift` | Home tab: contact, device, token, and configuration summary. |
| `push-token-repro/Views/Main/DeliveryView.swift` | Delivery tab: APNS/FCM registration actions, token override, and click-tracking controls. |
| `push-token-repro/Views/Main/LogView.swift` | Log tab: terminal-style console of SDK and demo log entries. |
| `push-token-repro/Views/Main/TechnicalDetailsView.swift` | Technical details sheet for SDK, session, notification, and configuration checks. |
| `push-token-repro/Views/Components/DesignSystem.swift` | Shared colors, typography, glass controls, settings rows, and icon treatment. |
| `push-token-repro/Configurations/APNS/Info.plist` | APNS app config: APNS app-key build setting, endpoint build setting, APNS demo URL scheme, and remote-notification background mode. |
| `push-token-repro/Configurations/FCM/Info.plist` | FCM app config: FCM app-key build setting, endpoint build setting, FCM demo URL scheme, and remote-notification background mode. |
| `push-token-repro/Configurations/BuildDefaults.xcconfig` | Committed non-secret defaults used by both app targets. |
| `push-token-repro/Configurations/Local.xcconfig.example` | Template for local app keys. Copy it to ignored `Local.xcconfig`. |
| `push-token-repro/GoogleService-Info.plist.example` | Shape of the Firebase plist. Copy/download a real `GoogleService-Info.plist` locally for the FCM target. |
| `NotificationServiceExtension/NotificationService.swift` | Rich push service extension wiring through shared `OrttoPushMessaging`. |

## Test Flow

1. Install fresh or clear app data before starting a clean run.
2. Let the first-open push permission request run before login.
3. Sign in with an email address.
4. Copy the support summary from Home if support needs the current state.
5. Open Delivery and register the selected target's APNS or FCM token.
6. Use "Redispatch cached token" to observe SDK token/session de-dupe behavior in Log.
7. Paste a tracked push-action deeplink in Delivery and run "Track link click" to verify click tracking logs.
8. Send a real notification with an action deeplink and confirm the tap is forwarded to the SDK.
9. Sign out to run the flow again.

## Build

### Local Configuration

The committed app `Info.plist` files intentionally do not contain Ortto app keys. Xcode expands the key and endpoint values from target `.xcconfig` files at build time.

```sh
cp push-token-repro/Configurations/Local.xcconfig.example push-token-repro/Configurations/Local.xcconfig
```

Then edit `push-token-repro/Configurations/Local.xcconfig`:

```xcconfig
ORTTO_APNS_APP_KEY = your-apns-demo-app-key
ORTTO_FCM_APP_KEY = your-fcm-demo-app-key
```

Only set the key for the target you are running. Set both keys when validating both `PushNotificationDemo-APNS` and `PushNotificationDemo-FCM`.

For FCM, also place a real Firebase plist at:

```text
push-token-repro/GoogleService-Info.plist
```

That file is bundled only when present. APNS does not need it.

Do not commit `push-token-repro/Configurations/Local.xcconfig` or `push-token-repro/GoogleService-Info.plist`.

```sh
xcodebuild -workspace push-token-repro.xcworkspace -scheme PushNotificationDemo-APNS -destination 'generic/platform=iOS Simulator' build
xcodebuild -workspace push-token-repro.xcworkspace -scheme PushNotificationDemo-FCM -destination 'generic/platform=iOS Simulator' build
```

Push delivery still needs a physical device and the existing Ortto staging push setup.
