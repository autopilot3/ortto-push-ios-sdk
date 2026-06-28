//
//  PushViewModel+Actions.swift
//  Ortto iOS SDK Push Demo
//
//  The demo's SDK flows. Each button action validates, calls the Ortto SDK
//  directly, and reports the outcome via `report`.
//

import Foundation
@preconcurrency import OrttoInAppNotifications
@preconcurrency import OrttoSDKCore
@preconcurrency import OrttoPushMessaging
import SwiftUI
import UIKit
import UserNotifications

// PushMessaging comes from the push package the running target links.
#if PUSH_DEMO_FCM
@preconcurrency import OrttoPushMessagingFCM
#else
@preconcurrency import OrttoPushMessagingAPNS
#endif

extension PushViewModel {
    // MARK: - Identify

    func runIdentifyAction() {
        report(.identify, .working, status: "Identifying signed-in account...", toast: "Identify started", "Calling Ortto.shared.identify.")
        identify(email: signedInEmail)
    }

    /// Surfaces an identify failure to the user. A server rejection (e.g. a 404 from
    /// a wrong endpoint/app key) is shown as `.blocked` with the actual server reason
    /// so a misconfiguration is visible, not silently swallowed; transient/timeout
    /// problems stay a softer `.warning`.
    func surfaceIdentifyFailure() {
        let reason = lastIdentifyError ?? "Identify did not complete."
        if reason.contains("Server error") {
            setActionStatus(.identify, "Ortto rejected identify — check endpoint / app key", tone: .blocked)
            showToast(
                title: "Identify rejected — check config",
                detail: "\(reason)\n\nVerify apiEndpoint and the app key in OrttoEnvironment.swift point at the same Ortto instance.",
                tone: .blocked
            )
        } else {
            setActionStatus(.identify, "Identify did not complete", tone: .warning)
            showToast(title: "Identify failed", detail: reason, tone: .warning)
        }
    }

    /// Identifies the signed-in contact. Calls the SDK directly —
    /// `Ortto.shared.identify(_:completion:)` is the integration point; the
    /// completion only drives UI state and surfaces failures.
    func identify(email rawEmail: String) {
        let cleaned = normalizedEmail(rawEmail)
        guard !cleaned.isEmpty else { return }

        isIdentifying = true
        let user = UserIdentifier(
            contactID: nil,
            email: cleaned,
            phone: nil,
            externalID: nil,
            firstName: nil,
            lastName: nil
        )

        appendLog("calling Ortto.shared.identify for \(cleaned)")
        Ortto.shared.identify(user) { [weak self] result in
            DispatchQueue.main.async { self?.handleIdentifyResult(result, email: cleaned) }
        }
    }

    /// Reacts to the SDK identify result: updates session state on success, and on
    /// failure stores + surfaces the reason (e.g. a 404 from a misconfigured
    /// endpoint/app key) so it isn't silently swallowed.
    private func handleIdentifyResult(_ result: Result<String, Error>, email: String) {
        isIdentifying = false
        switch result {
        case .success(let sessionID):
            lastIdentifiedEmail = email
            lastIdentifyError = nil
            appendLog("Ortto.shared.identify completed; session \(sessionID)")
            setActionStatus(.identify, "Identify complete; active session updated", tone: .success)
        case .failure(let error):
            lastIdentifyError = error.localizedDescription
            appendLog("Ortto.shared.identify failed: \(error.localizedDescription)")
            surfaceIdentifyFailure()
        }
        refreshState()
    }

    // MARK: - Login and logout

    func signIn(email rawEmail: String) {
        let cleaned = normalizedEmail(rawEmail)
        guard !cleaned.isEmpty else { return }
        cancelPendingFirstOpenPushForLogin()
        email = cleaned

        // Sign in locally right away, then identify in the background. Order vs.
        // identify doesn't matter; a failure surfaces via handleIdentifyResult.
        completeLogin(email: cleaned)
        identify(email: cleaned)
    }

    func completeLogin(email cleaned: String) {
        withAnimation(.easeInOut(duration: 0.34)) {
            signedInEmail = cleaned
            email = cleaned
            isUsingRememberedLogin = true
        }
        appendLog("customer signed in as \(cleaned)", dedupeKey: "signed-in:\(cleaned):\(Date().timeIntervalSince1970)")
    }

    func cancelPendingFirstOpenPushForLogin() {
        guard firstOpenPushTask != nil else { return }
        firstOpenPushTask?.cancel()
        firstOpenPushTask = nil
        appendLog("first-open push prompt deferred: login started", dedupeKey: "first-open:deferred:\(Date().timeIntervalSince1970)")
    }

    func logout() {
        if isLoggingOut {
            appendLog("logout skipped: already in flight", dedupeKey: "logout:in-flight")
            return
        }

        loginContinueTask?.cancel()
        loginContinueTask = nil
        isLoggingOut = true
        appendLog("calling Ortto.shared.clearIdentity")
        Task {
            let response = await sdkCallback { finish in
                Ortto.shared.clearIdentity { finish(String(describing: $0)) }
            }
            isLoggingOut = false
            appendLog("Ortto.shared.clearIdentity completed: \(response ?? "no response")")
            signedInEmail = ""
            isUsingRememberedLogin = true
            actionStatuses.removeAll()
            refreshState()
        }
    }

    // MARK: - Push registration

    func runRegisterPushAction() {
        let provider = activeProvider
        if let failure = orttoConfigurationFailure {
            appendLog("register \(provider.rawValue) blocked: \(AppConfiguration.orttoConfigurationFailureDetail)")
            report(.registerPush, .blocked, status: failure.title, toast: failure.title, failure.detail)
            return
        }

        if let failure = firebaseConfigurationFailure {
            failFirebaseConfiguration(reason: "register \(provider.rawValue)")
            report(.registerPush, .blocked, status: failure.title, toast: failure.title, "\(AppConfiguration.firebaseServiceInfoName).plist is missing from the app target.")
            return
        }

        if provider == .fcm && isGeneratedFCMToken(fcmToken) {
            appendLog("register FCM blocked: generated token detected", dedupeKey: "register:fcm:generated:\(Date().timeIntervalSince1970)")
            report(.registerPush, .blocked, status: "Generated FCM token blocked", toast: "Registration blocked", "That is a generated token, not a real FCM registration token.")
            return
        }

        report(.registerPush, .working, status: "Registering \(provider.rawValue)...", toast: "Registration started", "Registering \(provider.rawValue) push messaging.")
        Task {
            let didStart = await registerSelectedProvider()
            let message: String
            if didStart {
                message = provider == .apns
                    ? "APNS registration requested; waiting for device callback"
                    : "FCM registration requested; waiting for Firebase callback"
            } else {
                message = "Registration could not start; check the SDK log"
            }
            report(
                .registerPush,
                didStart ? .success : .warning,
                status: message,
                toast: didStart ? "Registration started" : "Registration failed",
                message
            )
        }
    }

    /// Requests permission and iOS remote-notification registration; the
    /// resulting token reaches the SDK via the AppDelegate callback (APNS) or
    /// the Firebase Messaging delegate (FCM).
    func registerSelectedProvider() async -> Bool {
        guard !isOrttoConfigurationMissing else {
            appendLog("register \(activeProvider.rawValue) blocked: \(AppConfiguration.orttoConfigurationFailureDetail)")
            return false
        }

        switch activeProvider {
        case .apns:
            await requestPushPermission(source: "APNS registration")
            return true
        case .fcm:
            guard firebaseConfigurationFailure == nil else {
                failFirebaseConfiguration(reason: "FCM registration")
                return false
            }
            await requestPushPermission(source: "FCM registration")
            if fcmToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                appendLog("waiting for Firebase Messaging registration token callback")
                return true
            }
            return registerFCMToken()
        }
    }

    func requestPushPermission(source: String) async {
        if isRequestingPush {
            appendLog("push permission skipped: request already in flight", dedupeKey: "push:in-flight")
            return
        }

        isRequestingPush = true
        appendLog("requesting push permission: \(source)")
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
            appendLog("push permission result granted=\(granted)")
        } catch {
            appendLog("push permission error: \(error.localizedDescription)")
            appendLog("push permission result granted=false")
        }
        isRequestingPush = false

        appendLog("calling registerForRemoteNotifications for \(activeProvider.rawValue)")
        UIApplication.shared.registerForRemoteNotifications()
        await refreshPermission()
    }

    /// Submits a pasted or Firebase-provided FCM token to the SDK.
    func registerFCMToken() -> Bool {
        let token = fcmToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            appendLog("FCM registration skipped: token is empty", dedupeKey: "fcm:empty")
            return false
        }
        guard !isGeneratedFCMToken(token) else {
            appendLog("FCM registration skipped: generated token detected", dedupeKey: "fcm:generated:\(Date().timeIntervalSince1970)")
            return false
        }

        if sdkToken == token, sdkTokenType == PushProvider.fcm.tokenType {
            appendLog(
                "FCM token registration de-duped; same token is already registered",
                dedupeKey: "fcm:dedupe:\(token)"
            )
            return true
        }

        appendLog("calling PushMessaging.registerDeviceToken(fcmToken:) with \(token)")
        #if PUSH_DEMO_FCM
        PushMessaging.shared.registerDeviceToken(fcmToken: token)
        after(0.8) { [self] in refreshState() }
        return true
        #else
        appLog.appError("FCM registration blocked: this APNS app target does not link OrttoPushMessagingFCM")
        appendLog("FCM registration blocked in \(appPushProvider.targetTitle) build", dedupeKey: "fcm:variant:failure:\(Date().timeIntervalSince1970)")
        return false
        #endif
    }

    func runRedispatchAction() {
        guard sdkToken != nil else {
            appendLog("re-dispatch skipped: no SDK token", dedupeKey: "redispatch:none")
            report(.redispatch, .blocked, status: "No SDK token to redispatch", toast: "Redispatch blocked", "Register a push token first.")
            return
        }

        report(.redispatch, .working, status: "Calling dispatchPushRequest...", toast: "Redispatch started", "Calling Ortto.shared.dispatchPushRequest.")
        Ortto.shared.dispatchPushRequest()
        appendLog("called Ortto.shared.dispatchPushRequest(); waiting for SDK logger output")
        after(0.8) { [self] in refreshState() }
        report(.redispatch, .success, status: "Redispatch called; watching SDK de-dupe logs", toast: "Redispatch called", "Watch Diagnostics for SDK de-dupe output.")
    }

    func runLogAPNSTokenAction() {
        refreshState(recordSnapshot: false)
        guard !apnsToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            appendLog("APNS token log blocked: no APNS token is available", dedupeKey: "apns:log:missing:\(Date().timeIntervalSince1970)")
            report(.logAPNSToken, .blocked, status: "Register APNS before logging the token", toast: "No APNS token", "Register APNS first, then log the full token.")
            return
        }

        print("Full APNS device token: \(apnsToken)")
        appLog.appInfo("Full APNS device token: \(apnsToken)")
        report(.logAPNSToken, .success, status: "Full APNS token written to Log and Xcode console", toast: "APNS token logged", "Full token written to Log and Xcode console.")
    }

    // MARK: - Click tracking

    func runTrackLinkAction() {
        let deepLink = trackedDeepLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !deepLink.isEmpty else {
            report(.trackLink, .blocked, status: "Paste a tracked push-action deeplink first", toast: "Missing deeplink", "Paste a push action deeplink containing tracking_url.")
            appendLog("link tracking blocked: no deeplink pasted", dedupeKey: "track-link:missing:\(Date().timeIntervalSince1970)")
            return
        }

        guard URL(string: deepLink) != nil else {
            report(.trackLink, .blocked, status: "Deeplink is not a valid URL", toast: "Invalid deeplink", "The pasted value is not a URL.")
            appendLog("link tracking blocked: invalid deeplink \(deepLink)", dedupeKey: "track-link:invalid:\(Date().timeIntervalSince1970)")
            return
        }

        guard deepLinkContainsTrackingURL(deepLink) else {
            report(.trackLink, .blocked, status: "Deeplink is missing tracking_url", toast: "Missing tracking URL", "Ortto click tracking requires a tracking_url query item.")
            appendLog("link tracking blocked: deeplink missing tracking_url \(deepLink)", dedupeKey: "track-link:no-tracking-url:\(Date().timeIntervalSince1970)")
            return
        }

        if sessionID == nil {
            appendLog("link tracking warning: no active SDK session before trackLinkClick", dedupeKey: "track-link:no-session:\(Date().timeIntervalSince1970)")
        }

        if let utmSummary = trackedUTMSummary(for: deepLink) {
            appendLog("deeplink UTM parameters: \(utmSummary)", dedupeKey: "track-link:utm:\(utmSummary):\(Date().timeIntervalSince1970)")
        }

        isTrackingLinkClick = true
        report(.trackLink, .working, status: "Calling Ortto.shared.trackLinkClick...", toast: "Tracking link", "Calling Ortto.shared.trackLinkClick.")
        appendLog("calling Ortto.shared.trackLinkClick for \(deepLink)")

        Task {
            let completed: Void? = await sdkCallback(timeout: 12) { finish in
                Ortto.shared.trackLinkClick(deepLink) { finish(()) }
            }
            isTrackingLinkClick = false
            if completed != nil {
                report(.trackLink, .success, status: "Click tracking request completed", toast: "Click tracked", "The SDK completed the link tracking call.")
                appendLog("Ortto.shared.trackLinkClick completed for \(deepLink)")
                refreshState()
            } else {
                report(.trackLink, .warning, status: "No completion yet; check the SDK log", toast: "Still waiting", "No SDK completion was received. Check Log for SDK output.")
                appendLog("Ortto.shared.trackLinkClick did not complete within 12s for \(deepLink)", dedupeKey: "track-link:timeout:\(Date().timeIntervalSince1970)")
            }
        }
    }

    // MARK: - In-app notifications (widgets)

    func runShowWidgetAction() {
        showWidget(id: widgetID.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Presents an in-app notification by ID — used by both the manual ID field
    /// and the fetched widget picker.
    func showWidget(id: String) {
        guard AppConfiguration.hasConfiguredCaptureJsURL else {
            report(.showWidget, .blocked, status: "Set ORTTO_CAPTURE_JS_URL to enable widgets", toast: "Widgets not configured", "Add a capture JS URL in Local.xcconfig, then rebuild.")
            appendLog("show widget blocked: ORTTO_CAPTURE_JS_URL not configured", dedupeKey: "widget:unconfigured:\(Date().timeIntervalSince1970)")
            return
        }

        guard !id.isEmpty else {
            report(.showWidget, .blocked, status: "Pick or enter a widget ID first", toast: "Missing widget ID", "Load the widget list or paste a widget ID.")
            appendLog("show widget blocked: no widget ID", dedupeKey: "widget:missing-id:\(Date().timeIntervalSince1970)")
            return
        }

        report(.showWidget, .working, status: "Calling OrttoCapture.shared.showWidget...", toast: "Showing widget", "Calling OrttoCapture.shared.showWidget.")
        appendLog("calling OrttoCapture.shared.showWidget for \(id)")

        // Ortto SDK: present a specific in-app notification (widget) by ID. The
        // SDK owns the WebView overlay, fetch, and dismissal.
        OrttoCapture.shared.showWidget(id).then { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success:
                    self.report(.showWidget, .success, status: "Widget shown", toast: "Widget shown", "The SDK presented the in-app notification.")
                    self.appendLog("OrttoCapture.shared.showWidget presented \(id)")
                case .failure(let error):
                    self.report(.showWidget, .warning, status: "Widget did not show; check the SDK log", toast: "Widget not shown", error.localizedDescription)
                    self.appendLog("OrttoCapture.shared.showWidget failed for \(id): \(error.localizedDescription)", dedupeKey: "widget:fail:\(id):\(Date().timeIntervalSince1970)")
                }
            }
        }
    }

    /// Lists the account's widgets so the tester can pick one instead of typing
    /// an ID. The SDK keeps its widget fetch internal, so this calls the same
    /// `/-/widgets/get` endpoint directly, then keeps only `popup` types —
    /// the only kind `showWidget` will actually render.
    func runLoadWidgetsAction() {
        guard AppConfiguration.canInitializeSDK else {
            report(.loadWidgets, .blocked, status: "Configure the SDK first", toast: "Not configured", AppConfiguration.orttoConfigurationFailureDetail)
            return
        }

        isLoadingWidgets = true
        report(.loadWidgets, .working, status: "Fetching widget list...", toast: "Loading widgets", "POST \(AppConfiguration.endpoint)/-/widgets/get")
        appendLog("fetching widget list: POST \(AppConfiguration.endpoint)/-/widgets/get")

        Task {
            do {
                let widgets = try await fetchWidgetList()
                let popups = widgets.filter { $0.type == "popup" }
                availableWidgets = popups
                isLoadingWidgets = false

                let hidden = widgets.count - popups.count
                let suffix = hidden > 0 ? "; \(hidden) non-popup hidden" : ""
                report(.loadWidgets, popups.isEmpty ? .warning : .success, status: "\(popups.count) popup widget(s)\(suffix)", toast: "Widgets loaded", "Found \(popups.count) popup widget(s)\(suffix).")
                appendLog("widget list loaded: \(popups.count) popup, \(hidden) other")
            } catch {
                isLoadingWidgets = false
                report(.loadWidgets, .warning, status: "Could not load widgets; check the log", toast: "Load failed", error.localizedDescription)
                appendLog("widget list fetch failed: \(error.localizedDescription)", dedupeKey: "widget:list:fail:\(Date().timeIntervalSince1970)")
            }
        }
    }

    /// Mirrors the SDK's internal widget fetch (same endpoint, same wire keys)
    /// since those types are not part of the SDK's public surface.
    private func fetchWidgetList() async throws -> [DemoWidget] {
        let base = AppConfiguration.endpoint
        let joined = base.hasSuffix("/") ? "\(base)-/widgets/get" : "\(base)/-/widgets/get"
        guard let url = URL(string: joined) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Wire keys match FetchWidgetsRequest: h = data-source key, s = session, tk = talk.
        // Widgets belong to the CAPTURE data source — using the push app key here
        // queries the wrong data source and always returns zero widgets.
        var body: [String: Any] = ["h": AppConfiguration.captureDataSourceKey, "tk": false, "ottlk": ""]
        if let session = Ortto.shared.userStorage.session { body["s"] = session }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        appendLog("widgets/get request body: \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "?")") // TEMP debug

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? -1
        let rawBody = String(data: data, encoding: .utf8) ?? "(non-utf8, \(data.count) bytes)"
        appendLog("widgets/get response HTTP \(code): \(rawBody)") // TEMP debug
        guard (200..<300).contains(code) else {
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "widgets/get returned HTTP \(code): \(rawBody)"])
        }

        let decoded = try JSONDecoder().decode(WidgetListResponse.self, from: data)
        return decoded.widgets.map { DemoWidget(id: $0.id, type: $0.type) }
    }

    // MARK: - Permission and state refresh

    func runRefreshPermissionAction() {
        report(.refreshPermission, .working, status: "Reading notification settings...", toast: "Refreshing permission", "Reading notification settings.")
        Task {
            let status = await refreshPermission()
            report(.refreshPermission, .success, status: "Permission status: \(status)", toast: "Permission refreshed", "Current status: \(status).")
        }
    }

    @discardableResult
    func refreshPermission() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:
            permissionStatus = "authorized"
        case .denied:
            permissionStatus = "denied"
        case .notDetermined:
            permissionStatus = "not determined"
        case .provisional:
            permissionStatus = "provisional"
        case .ephemeral:
            permissionStatus = "ephemeral"
        @unknown default:
            permissionStatus = "unknown"
        }
        refreshState(recordSnapshot: false)
        return permissionStatus
    }

    /// Re-reads the SDK session and registered token into published state.
    func refreshState(recordSnapshot: Bool = true) {
        sessionID = Ortto.shared.userStorage.session
        sdkToken = PushMessaging.shared.token?.value
        sdkTokenType = PushMessaging.shared.token?.type
        if activeProvider == .fcm,
           sdkTokenType == PushProvider.fcm.tokenType,
           let sdkToken,
           fcmToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fcmToken = sdkToken
        }
        apnsToken = DiagnosticsState.apnsDeviceTokenHex
        remoteRegistrationStatus = UIApplication.shared.isRegisteredForRemoteNotifications
            ? "registered with iOS"
            : "not registered with iOS"
        if sdkToken != nil, sdkTokenType == activeProvider.tokenType {
            setActionStatus(.registerPush, "\(activeProvider.rawValue) token registered with Ortto SDK", tone: .success)
        }

        if recordSnapshot {
            recordSessionSnapshot()
        }
    }

    // MARK: - Boot

    func prepareInitialState() {
        guard !hasPreparedInitialState else {
            refreshState()
            return
        }
        hasPreparedInitialState = true
        replayBufferedBootLogs()

        let rememberedEmail = normalizedEmail(lastIdentifiedEmail)
        if !rememberedEmail.isEmpty {
            isUsingRememberedLogin = true
            email = rememberedEmail
        }

        appendLog("app boot: provider \(activeProvider.rawValue), signedIn=\(isSignedIn)")
        if isFirebaseConfigurationMissing {
            failFirebaseConfiguration(reason: "app boot")
        }

        if !signedInEmail.isEmpty {
            email = signedInEmail
            appendLog("remembered account loaded: \(signedInEmail)")
            identify(email: signedInEmail)

            // Re-associate the stored push token with Ortto on every open. Fired
            // independently of identify — order doesn't matter, and the SDK
            // self-guards (no-ops) if no token has been registered yet.
            appendLog("app boot: dispatching stored push token")
            Ortto.shared.dispatchPushRequest()
        }

        refreshState(recordSnapshot: false)
        Task {
            await refreshPermission()
            if activeProvider == .fcm {
                startFCMBootstrapIfNeeded(reason: "app boot")
            }
        }
    }

    /// Console line for the `Ortto.shared.screen` calls each tab view makes
    /// in its own `onAppear`.
    func logScreenView(_ tab: AppTab) {
        appendLog("screen viewed: \(tab.screenName)", dedupeKey: "screen:\(tab.screenName)")
    }

    func performFirstOpenPushIfNeeded() {
        guard !hasAskedFirstOpenPush, firstOpenPushTask == nil else { return }
        guard !isOrttoConfigurationMissing else {
            appendLog("first-open push skipped: \(AppConfiguration.orttoConfigurationFailureDetail)", dedupeKey: "first-open:ortto-config")
            return
        }

        firstOpenPushTask = after(1.4) { [self] in
            firstOpenPushTask = nil
            guard !isIdentifying else { return }
            hasAskedFirstOpenPush = true
            Task { await requestPushPermission(source: "first open") }
        }
    }

    func startFCMBootstrapIfNeeded(reason: String) {
        guard activeProvider == .fcm, !hasStartedFCMBootstrap else { return }
        guard firebaseConfigurationFailure == nil else {
            hasStartedFCMBootstrap = true
            failFirebaseConfiguration(reason: "FCM bootstrap \(reason)")
            return
        }
        hasStartedFCMBootstrap = true
        appendLog("FCM bootstrap \(reason): requesting permission and remote registration")
        Task { await requestPushPermission(source: "FCM \(reason)") }
    }

    func failFirebaseConfiguration(reason: String) {
        appendLog(
            "configuration failure during \(reason): \(AppConfiguration.firebaseServiceInfoFailureDetail)",
            dedupeKey: "config:fcm:missing:\(reason)"
        )
    }

    /// Formats the UTM parameters the SDK extracts from a tracked deeplink,
    /// e.g. "utm_source=ortto utm_campaign=demo". Nil when none are present.
    func trackedUTMSummary(for deepLink: String) -> String? {
        guard let utm = Ortto.shared.retrieveUtmParameters(deepLink) else { return nil }
        let values: [(String, String?)] = [
            ("utm_source", utm.source),
            ("utm_medium", utm.medium),
            ("utm_campaign", utm.campaign),
            ("utm_content", utm.content),
            ("utm_term", utm.term)
        ]
        let formatted = values.compactMap { key, value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return "\(key)=\(value)"
        }
        return formatted.isEmpty ? nil : formatted.joined(separator: " ")
    }
}
