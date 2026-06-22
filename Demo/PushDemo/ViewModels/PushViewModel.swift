//
//  PushViewModel.swift
//  Ortto iOS SDK Push Demo
//
//  Demo state and UI plumbing (toasts, statuses, the log console feed).
//  The SDK flows themselves are in PushViewModel+Actions.swift.
//

import Combine
import Foundation
import OrttoSDKCore
import SwiftUI
import UIKit

// PushMessaging comes from the push package the running target links.
#if PUSH_DEMO_FCM
import OrttoPushMessagingFCM
#else
import OrttoPushMessagingAPNS
#endif

@MainActor
final class PushViewModel: ObservableObject {
    private let defaults: UserDefaults

    @Published var signedInEmail: String {
        didSet { defaults.set(signedInEmail, forKey: DefaultsKey.signedInEmail) }
    }
    @Published var hasAskedFirstOpenPush: Bool {
        didSet { defaults.set(hasAskedFirstOpenPush, forKey: DefaultsKey.hasAskedFirstOpenPush) }
    }
    @Published var lastIdentifiedEmail: String {
        didSet { defaults.set(lastIdentifiedEmail, forKey: DefaultsKey.lastIdentifiedEmail) }
    }

    @Published var email: String
    @Published var selectedTab: AppTab = .home
    @Published var sessionID: String?
    @Published var sdkToken: String?
    @Published var sdkTokenType: String?
    @Published var permissionStatus = "unknown"
    @Published var remoteRegistrationStatus = "unknown"
    @Published var apnsToken = DiagnosticsState.apnsDeviceTokenHex
    @Published var fcmToken = ""
    @Published var trackedDeepLink = ""
    @Published var widgetID = ""
    @Published var availableWidgets: [DemoWidget] = []
    @Published var isLoadingWidgets = false
    @Published var logEntries: [LogEntry] = []
    @Published var isIdentifying = false
    @Published var isLoggingOut = false
    @Published var isRequestingPush = false
    @Published var isTrackingLinkClick = false
    @Published var isUsingRememberedLogin = true
    @Published var isShowingTechnicalDetails = false
    @Published var actionStatuses: [SDKActionID: SDKActionStatus] = [:]
    @Published var actionToast: SDKToast?

    var logDedupeKeys: Set<String> = []
    var sessionSnapshotKeys: Set<String> = []
    var hasPreparedInitialState = false
    var hasStartedFCMBootstrap = false
    var firstOpenPushTask: Task<Void, Never>?
    var loginContinueTask: Task<Void, Never>?
    var toastDismissTask: Task<Void, Never>?

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
    func sdkCallback<T>(
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
