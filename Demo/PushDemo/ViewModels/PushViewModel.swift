//
//  PushViewModel.swift
//  Ortto iOS SDK Push Demo
//
//  Demo state and UI plumbing (toasts, statuses, the log console feed).
//  The SDK flows themselves are in PushViewModel+Actions.swift.
//

import Foundation
@preconcurrency import OrttoSDKCore
@preconcurrency import OrttoPushMessaging
import SwiftUI
import UIKit

// PushMessaging comes from the push package the running target links.
#if PUSH_DEMO_FCM
@preconcurrency import OrttoPushMessagingFCM
#else
@preconcurrency import OrttoPushMessagingAPNS
#endif

@MainActor
@Observable
final class PushViewModel {
    @ObservationIgnored private let defaults: UserDefaults

    var signedInEmail: String {
        didSet { defaults.set(signedInEmail, forKey: DefaultsKey.signedInEmail) }
    }
    var hasAskedFirstOpenPush: Bool {
        didSet { defaults.set(hasAskedFirstOpenPush, forKey: DefaultsKey.hasAskedFirstOpenPush) }
    }
    var lastIdentifiedEmail: String {
        didSet { defaults.set(lastIdentifiedEmail, forKey: DefaultsKey.lastIdentifiedEmail) }
    }

    var email: String
    var selectedTab: AppTab = .home
    /// Set when a notification's default (body-tap) action arrives, so the UI can
    /// present an in-app confirmation modal before navigating. Nil when dismissed.
    var deepLinkPrompt: DeepLinkPrompt?
    /// The reason the most recent identify failed (e.g. the server's 404 + body),
    /// surfaced to the user so a misconfigured endpoint/app key is visible, not silent.
    var lastIdentifyError: String?
    var sessionID: String?
    var sdkToken: String?
    var sdkTokenType: String?
    var permissionStatus = "unknown"
    var remoteRegistrationStatus = "unknown"
    var apnsToken = DiagnosticsState.apnsDeviceTokenHex
    var fcmToken = ""
    var trackedDeepLink = ""
    var widgetID = ""
    var availableWidgets: [DemoWidget] = []
    var isLoadingWidgets = false
    var logEntries: [LogEntry] = []
    var isIdentifying = false
    var isLoggingOut = false
    var isRequestingPush = false
    var isTrackingLinkClick = false
    var isUsingRememberedLogin = true
    var isShowingTechnicalDetails = false
    var actionStatuses: [SDKActionID: SDKActionStatus] = [:]
    var actionToast: SDKToast?

    @ObservationIgnored var logDedupeKeys: Set<String> = []
    @ObservationIgnored var sessionSnapshotKeys: Set<String> = []
    @ObservationIgnored var hasPreparedInitialState = false
    @ObservationIgnored var hasStartedFCMBootstrap = false
    @ObservationIgnored var firstOpenPushTask: Task<Void, Never>?
    @ObservationIgnored var loginContinueTask: Task<Void, Never>?
    @ObservationIgnored var toastDismissTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        signedInEmail = defaults.string(forKey: DefaultsKey.signedInEmail) ?? ""
        hasAskedFirstOpenPush = defaults.bool(forKey: DefaultsKey.hasAskedFirstOpenPush)
        lastIdentifiedEmail = defaults.string(forKey: DefaultsKey.lastIdentifiedEmail) ?? ""
        email = defaults.string(forKey: DefaultsKey.lastIdentifiedEmail) ?? ""
        sessionID = Ortto.shared.userStorage.session
        sdkToken = PushMessaging.shared.token?.value
        sdkTokenType = PushMessaging.shared.token?.type
    }

    deinit {
        firstOpenPushTask?.cancel()
        loginContinueTask?.cancel()
        toastDismissTask?.cancel()
    }

    // MARK: - Status and toast plumbing

    func setActionStatus(_ id: SDKActionID, _ text: String, tone: SDKActionTone) {
        withAnimation(.easeOut(duration: 0.18)) {
            actionStatuses[id] = SDKActionStatus(text: text, tone: tone)
        }
    }

    func showToast(title: String, detail: String, tone: SDKActionTone) {
        toastDismissTask?.cancel()

        withAnimation(.interpolatingSpring(stiffness: 260, damping: 26)) {
            actionToast = SDKToast(title: title, detail: detail, tone: tone)
        }

        toastDismissTask = after(2.4) { [self] in
            withAnimation(.easeOut(duration: 0.22)) {
                actionToast = nil
            }
        }
    }

    /// Paints an action's inline status and the floating toast in one call;
    /// every SDK action reports progress through this.
    func report(_ id: SDKActionID, _ tone: SDKActionTone, status: String, toast title: String, _ detail: String) {
        setActionStatus(id, status, tone: tone)
        showToast(title: title, detail: detail, tone: tone)
    }

    /// Runs `body` on the main actor after a delay; cancel the returned task
    /// to skip it.
    @discardableResult
    func after(_ seconds: Double, _ body: @escaping @MainActor () -> Void) -> Task<Void, Never> {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            body()
        }
    }

    /// Bridges a callback-style SDK API into async/await, optionally racing a
    /// timeout. Returns nil when the timeout fires first; a late SDK callback
    /// is then ignored.
    func sdkCallback<T: Sendable>(
        timeout: TimeInterval? = nil,
        _ start: (@escaping (T) -> Void) -> Void
    ) async -> T? {
        await withCheckedContinuation { continuation in
            let once = OnceFlag()
            let finish: (T?) -> Void = { value in
                guard once.claim() else { return }
                continuation.resume(returning: value)
            }
            if let timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { finish(nil) }
            }
            start { value in finish(value) }
        }
    }

    // MARK: - Clipboard

    func copySessionToken() {
        copyToClipboard(sessionID, label: "session token")
    }

    func copyCurrentPushToken() {
        copyToClipboard(currentPushToken, label: "\(activeProvider.rawValue) push token")
    }

    func copyToClipboard(_ value: String?, label: String) {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showToast(title: "Nothing to copy", detail: "No \(label) is available yet.", tone: .blocked)
            appendLog("copy blocked: missing \(label)", dedupeKey: "copy:\(label):missing:\(Date().timeIntervalSince1970)")
            return
        }

        UIPasteboard.general.string = value
        showToast(title: "Copied", detail: "\(label.capitalized) copied to clipboard.", tone: .success)
        appendLog("copied \(label) \(value)", dedupeKey: "copy:\(label):\(Date().timeIntervalSince1970)")
    }

    // MARK: - Log feed

    func receiveLogEntry(_ note: Notification) {
        guard let entry = note.userInfo?["entry"] as? LogEntry else { return }
        appendRawLog(entry)
        refreshState()
    }

    func appendLog(_ line: String, dedupeKey: String? = nil) {
        if let dedupeKey {
            guard !logDedupeKeys.contains(dedupeKey) else { return }
            logDedupeKeys.insert(dedupeKey)
        }

        appendRawLog(LogEntry(source: .demo, level: .info, message: line))
    }

    func appendRawLog(_ entry: LogEntry) {
        guard !logEntries.contains(where: { $0.id == entry.id }) else { return }
        logEntries.append(entry)
    }

    func replayBufferedBootLogs() {
        for entry in appLog.recentEntries {
            appendRawLog(entry)
        }
    }

    // MARK: - Deep links (notification tap / action routing)

    /// Routes a deeplink opened by the SDK after a notification tap or action
    /// button. The SDK calls `UIApplication.shared.open(_:)` with the action's
    /// link; iOS hands the app's own scheme (`ortto-demo-fcm`/`-apns`) back here
    /// via `RootView.onOpenURL`. The URL host selects the screen
    /// (e.g. `ortto-demo-fcm://delivery`); any `tracking_url` query is ignored —
    /// the SDK already tracked the click on its way through.
    func handleDeepLink(_ url: URL) {
        appendLog("deeplink opened: \(url.absoluteString)")

        let target = (url.host ?? url.pathComponents.first { $0 != "/" } ?? "").lowercased()
        switch target {
        case "confirm":
            // Default (body-tap) action: confirm in-app before doing anything.
            deepLinkPrompt = DeepLinkPrompt(link: url.absoluteString)
        case "delivery", "campaign", "push":
            selectedTab = .delivery
        case "log", "logs", "diagnostics":
            selectedTab = .diagnostics
        case "home", "":
            selectedTab = .home
        default:
            appendLog("deeplink host '\(target)' unrecognized — no screen change")
        }

        if !isSignedIn {
            appendLog("deeplink received while signed out — screen applies after sign-in")
        }
    }

    /// Confirms the pending default-action deeplink: dismiss the modal and
    /// navigate to the Delivery screen.
    func confirmDeepLinkPrompt() {
        if let link = deepLinkPrompt?.link {
            appendLog("deeplink confirmed: \(link) — opening Delivery")
        }
        deepLinkPrompt = nil
        selectedTab = .delivery
    }

    /// Dismisses the pending default-action deeplink without navigating.
    func dismissDeepLinkPrompt() {
        if let link = deepLinkPrompt?.link {
            appendLog("deeplink dismissed: \(link)")
        }
        deepLinkPrompt = nil
    }

    func recordSessionSnapshot() {
        let key = [
            sessionID ?? "anonymous",
            sdkTokenType ?? "none",
            sdkToken.map(short) ?? "no-token",
            permissionStatus
        ].joined(separator: "|")

        guard !sessionSnapshotKeys.contains(key) else { return }
        sessionSnapshotKeys.insert(key)
        appendLog(
            "session snapshot: \(sessionID ?? "anonymous") / \(sdkTokenType?.uppercased() ?? "NO TOKEN") / \(sdkToken ?? "no-token") / \(permissionStatus)",
            dedupeKey: "snapshot:\(key)"
        )
    }

    // MARK: - Small utilities

    func normalizedEmail(_ rawEmail: String) -> String {
        rawEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func isGeneratedFCMToken(_ value: String?) -> Bool {
        guard let value else { return false }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .hasPrefix("fcm_demo_")
    }

    func deepLinkContainsTrackingURL(_ value: String) -> Bool {
        guard let queryItems = URLComponents(string: value)?.queryItems else { return false }
        return queryItems.contains { item in
            item.name == "tracking_url" && !(item.value ?? "").isEmpty
        }
    }

    func short(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "anonymous" }
        if value.count <= 16 { return value }
        return "\(value.prefix(8))...\(value.suffix(6))"
    }
}

/// Thread-safe single-resume guard for `sdkCallback`.
private final class OnceFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if claimed { return false }
        claimed = true
        return true
    }
}
