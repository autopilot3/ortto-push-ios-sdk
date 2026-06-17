//
//  PushViewModel+DerivedState.swift
//  Ortto iOS SDK Push Demo
//

import Foundation
import SwiftUI

extension PushViewModel {
    var isSignedIn: Bool {
        !signedInEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var activeProvider: PushProvider {
        appPushProvider
    }

    var rememberedLoginEmail: String {
        normalizedEmail(lastIdentifiedEmail)
    }

    var visibleRememberedLoginEmail: String {
        isUsingRememberedLogin ? rememberedLoginEmail : ""
    }

    var rememberedContactValue: String {
        guard !rememberedLoginEmail.isEmpty else { return "No" }
        return rememberedLoginEmail == signedInEmail ? "Yes" : rememberedLoginEmail
    }

    var currentPushToken: String? {
        switch activeProvider {
        case .apns:
            if !apnsToken.isEmpty, !isGeneratedFCMToken(apnsToken) { return apnsToken }
            guard sdkTokenType == PushProvider.apns.tokenType, !isGeneratedFCMToken(sdkToken) else { return nil }
            return sdkToken
        case .fcm:
            let trimmed = fcmToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, !isGeneratedFCMToken(trimmed) { return trimmed }
            guard sdkTokenType == PushProvider.fcm.tokenType, !isGeneratedFCMToken(sdkToken) else { return nil }
            return sdkToken
        }
    }

    var hasGeneratedFCMToken: Bool {
        isGeneratedFCMToken(sdkToken) || isGeneratedFCMToken(fcmToken)
    }

    var isFirebaseConfigurationMissing: Bool {
        activeProvider == .fcm && !AppConfiguration.hasFirebaseServiceInfo
    }

    var isOrttoConfigurationMissing: Bool {
        !AppConfiguration.canInitializeSDK
    }

    var orttoConfigurationFailure: SDKConfigurationIssue? {
        guard isOrttoConfigurationMissing else { return nil }
        return SDKConfigurationIssue(
            title: "Ortto app key missing",
            detail: AppConfiguration.orttoConfigurationFailureDetail,
            severity: .critical
        )
    }

    var firebaseConfigurationFailure: SDKConfigurationIssue? {
        guard isFirebaseConfigurationMissing else { return nil }
        return SDKConfigurationIssue(
            title: "Firebase configuration failed",
            detail: AppConfiguration.firebaseServiceInfoFailureDetail,
            severity: .critical
        )
    }

    var blockingConfigurationIssues: [SDKConfigurationIssue] {
        configurationIssues.filter { $0.severity == .critical }
    }

    var currentRegisterTone: SDKActionTone {
        if isOrttoConfigurationMissing || isFirebaseConfigurationMissing || (activeProvider == .fcm && hasGeneratedFCMToken) {
            return .blocked
        }
        return .ready
    }

    var registrationActionTitle: String {
        if isOrttoConfigurationMissing {
            return "SDK config missing"
        }
        if isFirebaseConfigurationMissing || (activeProvider == .fcm && hasGeneratedFCMToken) {
            return activeProvider == .fcm ? "FCM blocked" : "Registration blocked"
        }
        return activeProvider == .fcm ? "Request FCM token" : "Register APNS token"
    }

    var homePushActionTint: Color {
        if isOrttoConfigurationMissing || isFirebaseConfigurationMissing || (activeProvider == .fcm && hasGeneratedFCMToken) {
            return AppColor.coral
        }
        return currentPushToken == nil ? AppColor.ink.opacity(0.58) : AppColor.ink
    }

    var homePushActionDisabled: Bool {
        isRequestingPush
    }

    var deliveryTokenStatus: String {
        if let currentPushToken {
            return short(currentPushToken)
        }
        return sdkToken == nil ? "No SDK token" : "\(sdkTokenType?.uppercased() ?? "SDK") token registered"
    }

    var currentIdentityStatus: String {
        sessionID == nil ? "No active session yet" : "Session is active"
    }

    var currentRegisterStatus: String {
        if isOrttoConfigurationMissing {
            return "Ortto app key missing"
        }

        switch activeProvider {
        case .apns:
            return sdkTokenType == PushProvider.apns.tokenType ? "APNS token registered" : "Ready to request APNS registration"
        case .fcm:
            if isFirebaseConfigurationMissing {
                return "Firebase configuration failed: \(AppConfiguration.firebaseServiceInfoName).plist missing"
            }
            if isGeneratedFCMToken(fcmToken) {
                return "Generated FCM token blocked"
            }
            if sdkTokenType == PushProvider.fcm.tokenType {
                return "FCM token registered"
            }
            if !fcmToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Ready to submit pasted FCM token"
            }
            return "Ready to request Firebase registration token"
        }
    }

    var pushTokenPlaceholder: String {
        if isOrttoConfigurationMissing {
            return "Ortto app key missing"
        }
        if isFirebaseConfigurationMissing {
            return "Firebase configuration failed: \(AppConfiguration.firebaseServiceInfoName).plist missing"
        }
        if activeProvider == .fcm && hasGeneratedFCMToken {
            return "invalid generated token blocked"
        }
        return "No \(activeProvider.rawValue) token yet"
    }

    var currentRedispatchStatus: String {
        sdkToken == nil ? "Needs an SDK token first" : "SDK token ready to redispatch"
    }

    var currentTrackLinkStatus: String {
        let value = trackedDeepLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "Paste a tracked push-action deeplink" }
        guard URL(string: value) != nil else { return "Deeplink is not a valid URL" }
        guard deepLinkContainsTrackingURL(value) else { return "Deeplink is missing tracking_url" }
        return "Tracked deeplink ready"
    }

    var currentTrackLinkTone: SDKActionTone {
        let value = trackedDeepLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .ready }
        guard URL(string: value) != nil, deepLinkContainsTrackingURL(value) else { return .warning }
        return .ready
    }

    var currentPermissionStatus: String {
        "Permission status: \(permissionStatus)"
    }

    var currentLogAPNSStatus: String {
        apnsToken.isEmpty ? "Register APNS before logging the token" : "APNS token ready to log"
    }

    var configurationIssues: [SDKConfigurationIssue] {
        var issues: [SDKConfigurationIssue] = []

        if sessionID == nil {
            issues.append(
                SDKConfigurationIssue(
                    title: "No active SDK session",
                    detail: "Identify needs to complete before token dispatch can be tied to a user.",
                    severity: .warning
                )
            )
        }

        if let orttoConfigurationFailure {
            issues.append(orttoConfigurationFailure)
        }

        if activeProvider == .fcm && hasGeneratedFCMToken {
            issues.append(
                SDKConfigurationIssue(
                    title: "Invalid generated FCM token detected",
                    detail: "A previous build remembered an fcm_demo token. Paste or register a real Firebase token before using FCM results.",
                    severity: .critical
                )
            )
        }

        if let firebaseConfigurationFailure {
            issues.append(firebaseConfigurationFailure)
        }

        if permissionStatus == "denied" {
            issues.append(
                SDKConfigurationIssue(
                    title: "Push permission denied",
                    detail: "iOS will not deliver notifications until permission is re-enabled in Settings.",
                    severity: .critical
                )
            )
        } else if permissionStatus == "not determined" {
            issues.append(
                SDKConfigurationIssue(
                    title: "Push permission has not been requested",
                    detail: "Run registration to trigger the notification permission path.",
                    severity: .warning
                )
            )
        }

        if let sdkTokenType, sdkTokenType != activeProvider.tokenType {
            issues.append(
                SDKConfigurationIssue(
                    title: "SDK token provider does not match",
                    detail: "The active target is \(activeProvider.rawValue), but the SDK token is \(sdkTokenType.uppercased()).",
                    severity: .warning
                )
            )
        }

        if activeProvider == .fcm &&
            !isFirebaseConfigurationMissing &&
            fcmToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            sdkTokenType != PushProvider.fcm.tokenType {
            issues.append(
                SDKConfigurationIssue(
                    title: "Waiting for Firebase token",
                    detail: "The FCM package is selected. The app should log Firebase configuration, APNS bridging, and token callbacks at boot.",
                    severity: .warning
                )
            )
        }

        if sdkToken == nil {
            issues.append(
                SDKConfigurationIssue(
                    title: "No SDK push token",
                    detail: "Register \(activeProvider.rawValue) to populate PushMessaging.shared.token.",
                    severity: .warning
                )
            )
        }

        if AppConfiguration.deepLinkScheme.isEmpty {
            issues.append(
                SDKConfigurationIssue(
                    title: "Deep link scheme missing",
                    detail: "No URL scheme is declared in CFBundleURLTypes, so notification action deeplinks may not open.",
                    severity: .critical
                )
            )
        }

        return issues
    }

    func actionStatus(
        _ id: SDKActionID,
        fallback: String,
        tone: SDKActionTone = .ready
    ) -> SDKActionStatus {
        actionStatuses[id] ?? SDKActionStatus(text: fallback, tone: tone)
    }
}
